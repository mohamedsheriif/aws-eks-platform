include "root" {
  path = find_in_parent_folders("root.hcl")
}

locals {
  env = read_terragrunt_config(find_in_parent_folders("env.hcl")).locals
}

terraform {
  source = "${get_repo_root()}/modules/waf"
}

# Web ACLs for the two internet-facing entry points. AWS managed rule groups block common
# exploits, known bad inputs and IPs with a bad reputation; a per-IP rate limit blocks floods.
inputs = {
  project = local.env.project
  env     = local.env.env
  tags    = local.env.tags

  web_acls = {
    # Assets CloudFront distribution: static files only.
    cloudfront = {
      name  = "${local.env.project}-${local.env.env}-cloudfront"
      scope = "CLOUDFRONT"
      managed_rule_groups = [
        "AWSManagedRulesAmazonIpReputationList",
        "AWSManagedRulesCommonRuleSet",
        "AWSManagedRulesKnownBadInputsRuleSet",
      ]
      rate_limit = 2000
    }

    # Public ALB in front of the microservices' APIs, backed by PostgreSQL.
    alb-public = {
      name  = "${local.env.project}-${local.env.env}-alb-public"
      scope = "REGIONAL"
      managed_rule_groups = [
        "AWSManagedRulesAmazonIpReputationList",
        "AWSManagedRulesCommonRuleSet",
        "AWSManagedRulesKnownBadInputsRuleSet",
        "AWSManagedRulesSQLiRuleSet",
      ]
      rate_limit = 1000
    }
  }
}
