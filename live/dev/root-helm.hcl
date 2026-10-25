# Root for units that deploy into the cluster (helm-core, helm-platform). Same backend
# as root.hcl, plus the helm and kubectl providers.
#
# The providers read ~/.kube/config. Create it first (from the tailnet, the API is private):
#   aws eks update-kubeconfig --name <project>-<env> --region <region> --profile <aws_profile>
#
# TG_MOCK=true uses local state, fake AWS credentials and a placeholder cluster.

locals {
  env        = read_terragrunt_config("${get_parent_terragrunt_dir()}/env.hcl").locals
  account_id = local.env.account_id

  # AWS CLI profile for local runs (~/.aws/config). Ignored in CI.
  aws_profile = get_env("CI", "") == "true" ? "" : local.env.aws_profile

  state_bucket = local.env.state_bucket

  # The context name aws eks update-kubeconfig creates.
  kube_context = "arn:aws:eks:${local.env.region}:${local.account_id}:cluster/${local.env.project}-${local.env.env}"

  mock = get_env("TG_MOCK", "false") == "true"

  backend_s3 = <<-EOF
    terraform {
      backend "s3" {
        bucket       = "${local.state_bucket}"
        key          = "${get_path_from_repo_root()}/terraform.tfstate"
        region       = "${local.env.region}"
        encrypt      = true
        use_lockfile = true%{if local.aws_profile != ""}
        profile      = "${local.aws_profile}"%{endif}
      }
    }
  EOF

  backend_local = <<-EOF
    terraform {
      backend "local" {}
    }
  EOF

  provider_real = <<-EOF
    provider "aws" {
      region              = "${local.env.region}"
      allowed_account_ids = ["${local.account_id}"]%{if local.aws_profile != ""}
      profile             = "${local.aws_profile}"%{endif}
    }

    provider "helm" {
      kubernetes = {
        config_path    = "~/.kube/config"
        config_context = "${local.kube_context}"
      }
    }

    provider "kubectl" {
      config_path      = "~/.kube/config"
      config_context   = "${local.kube_context}"
      load_config_file = true
    }
  EOF

  provider_mock = <<-EOF
    provider "aws" {
      region                      = "${local.env.region}"
      access_key                  = "mock"
      secret_key                  = "mock"
      skip_credentials_validation = true
      skip_requesting_account_id  = true
      skip_metadata_api_check     = true
      skip_region_validation      = true
    }

    provider "helm" {
      kubernetes = {
        host     = "https://mock.eks.amazonaws.com"
        insecure = true
      }
    }

    provider "kubectl" {
      host             = "https://mock.eks.amazonaws.com"
      insecure         = true
      load_config_file = false
    }
  EOF
}

terragrunt_version_constraint = ">= 0.90.0, < 1.0.0"
terraform_version_constraint  = ">= 1.10.0, < 2.0.0"

generate "backend" {
  path      = "state.tf"
  if_exists = "overwrite_terragrunt"
  contents  = local.mock ? local.backend_local : local.backend_s3
}

generate "provider" {
  path      = "provider.tf"
  if_exists = "overwrite_terragrunt"
  contents  = local.mock ? local.provider_mock : local.provider_real
}
