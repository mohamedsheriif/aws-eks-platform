include "root" {
  path = find_in_parent_folders("root.hcl")
}

locals {
  env = read_terragrunt_config(find_in_parent_folders("env.hcl")).locals
}

terraform {
  source = "${get_repo_root()}/modules/rds"
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
    security_group_ids = { rds = "sg-mock-rds" }
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan"]
}

dependency "kms" {
  config_path = "../kms"

  mock_outputs = {
    kms_key_arns = {
      rds     = "arn:aws:kms:us-east-1:111111111111:key/mock-rds"
      secrets = "arn:aws:kms:us-east-1:111111111111:key/mock-secrets"
    }
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan"]
}

inputs = {
  project    = local.env.project
  env        = local.env.env
  tags       = local.env.tags
  subnet_ids = dependency.vpc.outputs.subnet_ids

  subnet_groups = {
    main = {
      name        = "${local.env.project}-${local.env.env}-postgres"
      description = "Private subnets for PostgreSQL"
      subnet_keys = ["private-us-east-1a", "private-us-east-1b"]
    }
  }

  # rds.force_ssl rejects any connection that isn't TLS.
  parameters = {
    main = {
      name   = "${local.env.project}-${local.env.env}-postgres17"
      family = "postgres17"
      parameter = [
        { name = "rds.force_ssl", value = "1" },
      ]
    }
  }

  # Apps connect with IAM auth tokens; the master password lives in an RDS-managed secret.
  rds = {
    main = {
      identifier                    = "${local.env.project}-${local.env.env}-postgres"
      engine                        = "postgres"
      engine_version                = "17"
      instance_class                = "db.t4g.micro"
      db_name                       = local.env.project
      username                      = "${local.env.project}_admin"
      allocated_storage             = 20
      max_allocated_storage         = 50
      kms_key_id                    = dependency.kms.outputs.kms_key_arns["rds"]
      master_user_secret_kms_key_id = dependency.kms.outputs.kms_key_arns["secrets"]
      vpc_security_group_ids        = [dependency.security_groups_data.outputs.security_group_ids["rds"]]
      db_subnet_group_key_name      = "main"
      parameter_group_key_name      = "main"
      multi_az                      = false
      backup_retention_period       = 1
      skip_final_snapshot           = true
      deletion_protection           = false
    }
  }
}
