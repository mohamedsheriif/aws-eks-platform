include "root" {
  path = find_in_parent_folders("root.hcl")
}

locals {
  env = read_terragrunt_config(find_in_parent_folders("env.hcl")).locals
}

terraform {
  source = "${get_repo_root()}/modules/iam-oidc"
}

# Lets GitHub Actions in this repository assume AWS roles with short-lived tokens,
# so CI needs no stored AWS keys. Applied by scripts/bootstrap.sh.
inputs = {
  project = local.env.project
  env     = local.env.env
  tags    = local.env.tags

  oidc_providers = {
    github = {
      url       = "https://token.actions.githubusercontent.com"
      audiences = ["sts.amazonaws.com"]
    }
  }

  roles = {
    # Pull requests and main: read-only, for terragrunt plan. Can write only the state lock files.
    github-plan = {
      name              = "${local.env.project}-${local.env.env}-github-plan"
      description       = "terragrunt plan from pull requests and main"
      oidc_provider_key = "github"
      audience          = "sts.amazonaws.com"
      subjects = [
        "repo:mohamedsheriif/aws-eks-platform:pull_request",
        "repo:mohamedsheriif/aws-eks-platform:ref:refs/heads/main",
      ]
      policy_arns = ["arn:aws:iam::aws:policy/ReadOnlyAccess"]
      inline_policies = {
        state-lock = jsonencode({
          Version = "2012-10-17"
          Statement = [{
            Effect   = "Allow"
            Action   = ["s3:PutObject", "s3:DeleteObject"]
            Resource = "arn:aws:s3:::${local.env.state_bucket}/*.tflock"
          }]
        })
      }
    }

    # Applies: only jobs that run in the protected "dev" GitHub environment,
    # which can require a reviewer's approval before the job starts.
    github-apply = {
      name              = "${local.env.project}-${local.env.env}-github-apply"
      description       = "terragrunt apply from the dev GitHub environment"
      oidc_provider_key = "github"
      audience          = "sts.amazonaws.com"
      subjects          = ["repo:mohamedsheriif/aws-eks-platform:environment:${local.env.env}"]
      policy_arns       = ["arn:aws:iam::aws:policy/AdministratorAccess"]
    }
  }
}
