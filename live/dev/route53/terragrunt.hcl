include "root" {
  path = find_in_parent_folders("root.hcl")
}

locals {
  env = read_terragrunt_config(find_in_parent_folders("env.hcl")).locals
}

terraform {
  source = "${get_repo_root()}/modules/route53"
}

inputs = {
  project = local.env.project
  env     = local.env.env
  tags    = local.env.tags

  # Delegated from the prod account's shopflow.com zone with an NS record (live/prod/route53).
  zones = {
    main = {
      name          = local.env.domain
      force_destroy = true
    }
  }
}
