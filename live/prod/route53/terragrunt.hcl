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

  zones = {
    main = {
      name = local.env.domain
    }
  }

  # dev.shopflow.com is a separate zone in the dev account. These are its name servers:
  # run `terragrunt output name_servers` in live/dev/route53 and paste the four values.
  records = {
    dev-delegation = {
      zone_key = "main"
      name     = "dev.${local.env.domain}"
      type     = "NS"
      ttl      = 172800
      records = [
        "ns-0000.awsdns-00.com.",
        "ns-0000.awsdns-00.net.",
        "ns-0000.awsdns-00.org.",
        "ns-0000.awsdns-00.co.uk.",
      ]
    }
  }
}
