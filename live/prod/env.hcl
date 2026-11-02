locals {
  project    = "shopflow"
  env        = "prod"
  region     = "us-east-1"
  account_id = "222222222222"

  domain = "shopflow.com"

  state_bucket = "${local.project}-${local.env}-tfstate-${local.account_id}"

  # AWS CLI profile for local runs (~/.aws/config).
  aws_profile = "${local.project}-${local.env}"

  tags = {
    Project     = local.project
    Environment = local.env
    Owner       = "devops"
    ManagedBy   = "terragrunt"
  }
}
