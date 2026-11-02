include "root" {
  path = find_in_parent_folders("root.hcl")
}

locals {
  env = read_terragrunt_config(find_in_parent_folders("env.hcl")).locals
}

terraform {
  source = "${get_repo_root()}/modules/acm"
}

dependency "route53" {
  config_path = "../route53"

  mock_outputs = {
    zone_ids = { main = "Z0000000000MOCK" }
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan"]
}

inputs = {
  project = local.env.project
  env     = local.env.env
  tags    = local.env.tags

  # Issued in us-east-1, so the same certificate serves the ALBs and CloudFront.
  acm = {
    main = {
      domain_name               = local.env.domain
      subject_alternative_names = ["*.${local.env.domain}"]
      route53_zone_id           = dependency.route53.outputs.zone_ids["main"]
    }
  }
}
