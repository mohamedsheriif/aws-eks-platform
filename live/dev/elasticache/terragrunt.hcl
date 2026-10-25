include "root" {
  path = find_in_parent_folders("root.hcl")
}

locals {
  env = read_terragrunt_config(find_in_parent_folders("env.hcl")).locals
}

terraform {
  source = "${get_repo_root()}/modules/elasticache"
}

dependency "vpc" {
  config_path = "../vpc"

  mock_outputs = {
    subnet_ids = {
      private-us-east-1a = "subnet-mock-private-a"
      private-us-east-1b = "subnet-mock-private-b"
    }
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan"]
}

dependency "security_groups_data" {
  config_path = "../security-groups-data"

  mock_outputs = {
    security_group_ids = { redis = "sg-mock-redis" }
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan"]
}

dependency "kms" {
  config_path = "../kms"

  mock_outputs = {
    kms_key_arns = { elasticache = "arn:aws:kms:us-east-1:111111111111:key/mock-elasticache" }
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan"]
}

inputs = {
  project = local.env.project
  env     = local.env.env
  tags    = local.env.tags

  subnet_groups = {
    main = {
      name       = "${local.env.project}-${local.env.env}-valkey"
      subnet_ids = [dependency.vpc.outputs.subnet_ids["private-us-east-1a"], dependency.vpc.outputs.subnet_ids["private-us-east-1b"]]
    }
  }

  # TLS required, encrypted at rest, IAM authentication only. One node.
  cache = {
    main = {
      cluster_name             = "${local.env.project}-${local.env.env}-valkey"
      description              = "Valkey cache for the microservices"
      engine                   = "valkey"
      engine_version           = "8.0"
      node_type                = "cache.t4g.micro"
      parameter_group_name     = "default.valkey8"
      num_cache_clusters       = 1
      snapshot_retention_limit = 0
      subnet_group_key_name    = "main"
      security_group_ids       = [dependency.security_groups_data.outputs.security_group_ids["redis"]]
      kms_key_id               = dependency.kms.outputs.kms_key_arns["elasticache"]

      # Each service gets its own user, limited to its own key prefix.
      iam_users = {
        orders  = { access_string = "on ~orders:* +@all -@dangerous" }
        catalog = { access_string = "on ~catalog:* +@all -@dangerous" }
      }
    }
  }
}
