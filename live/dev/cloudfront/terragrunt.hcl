include "root" {
  path = find_in_parent_folders("root.hcl")
}

locals {
  env = read_terragrunt_config(find_in_parent_folders("env.hcl")).locals
}

terraform {
  source = "${get_repo_root()}/modules/cloudfront"
}

dependency "acm" {
  config_path = "../acm"

  mock_outputs = {
    cert_arns = { main = "arn:aws:acm:us-east-1:111111111111:certificate/mock" }
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan"]
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

  origin_access_controls = {
    assets = {
      name        = "${local.env.project}-${local.env.env}-assets"
      description = "SigV4 access to the private assets bucket"
    }
  }

  # The assets bucket is created by the s3 unit after this one; its name is known in advance,
  # and its bucket policy allows only this distribution.
  cloudfront_distributions = {
    assets = {
      comment         = "${local.env.project}-${local.env.env} static assets"
      aliases         = ["assets.${local.env.domain}"]
      route53_zone_id = dependency.route53.outputs.zone_ids["main"]
      is_ipv6_enabled = true
      http_version    = "http2and3"

      origins = {
        assets = {
          origin_id                 = "assets"
          origin_domain_name        = "${local.env.project}-${local.env.env}-assets-${local.env.account_id}.s3.${local.env.region}.amazonaws.com"
          origin_access_control_key = "assets"
        }
      }

      default_cache_behavior = {
        target_origin_id = "assets"
        cache_policy_id  = "658327ea-f89d-4fab-a63d-7e88639e58f6" # Managed-CachingOptimized
      }

      viewer_certificate = {
        acm_certificate_arn = dependency.acm.outputs.cert_arns["main"]
      }
    }
  }
}
