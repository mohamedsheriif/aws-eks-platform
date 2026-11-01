include "root" {
  path = find_in_parent_folders("root.hcl")
}

locals {
  env = read_terragrunt_config(find_in_parent_folders("env.hcl")).locals
}

terraform {
  source = "${get_repo_root()}/modules/ses"
}

dependency "route53" {
  config_path = "../route53"

  mock_outputs = {
    zone_ids = { main = "Z0000000000MOCK" }
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan"]
}

inputs = {
  # Used by the notifications service. Its Pod Identity role may only send through
  # this identity and configuration set.
  ses_configuration_sets = {
    main = {
      name = "${local.env.project}-${local.env.env}"
    }
  }

  # Domain identity verified with Easy DKIM; the three DKIM CNAMEs are published in the dev zone.
  ses_identities = {
    main = {
      email_identity         = local.env.domain
      configuration_set_name = "${local.env.project}-${local.env.env}"
      route53_zone_id        = dependency.route53.outputs.zone_ids["main"]
    }
  }
}
