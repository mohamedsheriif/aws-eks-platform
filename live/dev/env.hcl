locals {
  project    = "shopflow"
  env        = "dev"
  region     = "us-east-1"
  account_id = "111111111111"

  domain = "dev.shopflow.com"

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
