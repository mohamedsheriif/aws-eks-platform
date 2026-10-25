include "root" {
  path = find_in_parent_folders("root.hcl")
}

locals {
  env = read_terragrunt_config(find_in_parent_folders("env.hcl")).locals
}

terraform {
  source = "${get_repo_root()}/modules/s3"
}

dependency "kms" {
  config_path = "../kms"

  mock_outputs = {
    kms_key_arns = { s3 = "arn:aws:kms:us-east-1:111111111111:key/mock" }
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan"]
}

dependency "cloudfront" {
  config_path = "../cloudfront"

  mock_outputs = {
    cloudfront_distribution_arns = { assets = "arn:aws:cloudfront::111111111111:distribution/EMOCK" }
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan"]
}

inputs = {
  project = local.env.project
  env     = local.env.env
  tags    = local.env.tags

  buckets = {
    # Static assets, readable only by the assets CloudFront distribution.
    assets = {
      name               = "${local.env.project}-${local.env.env}-assets-${local.env.account_id}"
      force_destroy      = true
      sse_algorithm      = "aws:kms"
      kms_master_key_id  = dependency.kms.outputs.kms_key_arns["s3"]
      bucket_key_enabled = true

      bucket_policy = jsonencode({
        Version = "2012-10-17"
        Statement = [
          {
            Sid       = "DenyInsecureTransport"
            Effect    = "Deny"
            Principal = "*"
            Action    = "s3:*"
            Resource = [
              "arn:aws:s3:::${local.env.project}-${local.env.env}-assets-${local.env.account_id}",
              "arn:aws:s3:::${local.env.project}-${local.env.env}-assets-${local.env.account_id}/*",
            ]
            Condition = { Bool = { "aws:SecureTransport" = "false" } }
          },
          {
            Sid       = "AllowCloudFrontOAC"
            Effect    = "Allow"
            Principal = { Service = "cloudfront.amazonaws.com" }
            Action    = "s3:GetObject"
            Resource  = "arn:aws:s3:::${local.env.project}-${local.env.env}-assets-${local.env.account_id}/*"
            Condition = { StringEquals = { "AWS:SourceArn" = dependency.cloudfront.outputs.cloudfront_distribution_arns["assets"] } }
          },
        ]
      })
    }

    # Application data, accessed by the microservices through their Pod Identity roles.
    data = {
      name               = "${local.env.project}-${local.env.env}-data-${local.env.account_id}"
      force_destroy      = true
      sse_algorithm      = "aws:kms"
      kms_master_key_id  = dependency.kms.outputs.kms_key_arns["s3"]
      bucket_key_enabled = true

      bucket_policy = jsonencode({
        Version = "2012-10-17"
        Statement = [
          {
            Sid       = "DenyInsecureTransport"
            Effect    = "Deny"
            Principal = "*"
            Action    = "s3:*"
            Resource = [
              "arn:aws:s3:::${local.env.project}-${local.env.env}-data-${local.env.account_id}",
              "arn:aws:s3:::${local.env.project}-${local.env.env}-data-${local.env.account_id}/*",
            ]
            Condition = { Bool = { "aws:SecureTransport" = "false" } }
          },
        ]
      })
    }

    # Loki chunks and index. Loki's compactor enforces the 14-day retention; the lifecycle rule is a backstop.
    loki = {
      name               = "${local.env.project}-${local.env.env}-loki-${local.env.account_id}"
      force_destroy      = true
      sse_algorithm      = "aws:kms"
      kms_master_key_id  = dependency.kms.outputs.kms_key_arns["s3"]
      bucket_key_enabled = true

      lifecycle_enabled = true
      expiration_days   = 14

      bucket_policy = jsonencode({
        Version = "2012-10-17"
        Statement = [
          {
            Sid       = "DenyInsecureTransport"
            Effect    = "Deny"
            Principal = "*"
            Action    = "s3:*"
            Resource = [
              "arn:aws:s3:::${local.env.project}-${local.env.env}-loki-${local.env.account_id}",
              "arn:aws:s3:::${local.env.project}-${local.env.env}-loki-${local.env.account_id}/*",
            ]
            Condition = { Bool = { "aws:SecureTransport" = "false" } }
          },
        ]
      })
    }
  }
}
