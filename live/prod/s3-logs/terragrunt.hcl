include "root" {
  path = find_in_parent_folders("root.hcl")
}

locals {
  env = read_terragrunt_config(find_in_parent_folders("env.hcl")).locals
}

terraform {
  source = "${get_repo_root()}/modules/s3"
}

# Separate from the s3 unit so the VPC (flow logs) can depend on it without waiting for
# CloudFront. Encrypted with SSE-S3 because ALB access logs don't support SSE-KMS.
inputs = {
  project = local.env.project
  env     = local.env.env
  tags    = local.env.tags

  buckets = {
    # VPC flow logs and CloudFront access logs under AWSLogs/, ALB access logs under alb/.
    logs = {
      name               = "${local.env.project}-${local.env.env}-logs-${local.env.account_id}"
      versioning_enabled = true

      lifecycle_enabled = true
      noncurrent_days   = 30
      transitions       = [{ days = 30, storage_class = "STANDARD_IA" }]
      expiration_days   = 365

      bucket_policy = jsonencode({
        Version = "2012-10-17"
        Statement = [
          {
            Sid       = "DenyInsecureTransport"
            Effect    = "Deny"
            Principal = "*"
            Action    = "s3:*"
            Resource = [
              "arn:aws:s3:::${local.env.project}-${local.env.env}-logs-${local.env.account_id}",
              "arn:aws:s3:::${local.env.project}-${local.env.env}-logs-${local.env.account_id}/*",
            ]
            Condition = { Bool = { "aws:SecureTransport" = "false" } }
          },
          {
            # Elastic Load Balancing writes ALB access logs from its own account in us-east-1.
            Sid       = "ALBAccessLogs"
            Effect    = "Allow"
            Principal = { AWS = "arn:aws:iam::127311923021:root" }
            Action    = "s3:PutObject"
            Resource  = "arn:aws:s3:::${local.env.project}-${local.env.env}-logs-${local.env.account_id}/alb/AWSLogs/${local.env.account_id}/*"
          },
          {
            # Log delivery service used by VPC flow logs and CloudFront standard logging.
            Sid       = "LogDeliveryWrite"
            Effect    = "Allow"
            Principal = { Service = "delivery.logs.amazonaws.com" }
            Action    = "s3:PutObject"
            Resource  = "arn:aws:s3:::${local.env.project}-${local.env.env}-logs-${local.env.account_id}/AWSLogs/${local.env.account_id}/*"
            Condition = {
              StringEquals = { "aws:SourceAccount" = local.env.account_id }
              ArnLike      = { "aws:SourceArn" = "arn:aws:logs:${local.env.region}:${local.env.account_id}:*" }
            }
          },
          {
            Sid       = "LogDeliveryCheck"
            Effect    = "Allow"
            Principal = { Service = "delivery.logs.amazonaws.com" }
            Action    = ["s3:GetBucketAcl", "s3:ListBucket"]
            Resource  = "arn:aws:s3:::${local.env.project}-${local.env.env}-logs-${local.env.account_id}"
            Condition = {
              StringEquals = { "aws:SourceAccount" = local.env.account_id }
              ArnLike      = { "aws:SourceArn" = "arn:aws:logs:${local.env.region}:${local.env.account_id}:*" }
            }
          },
        ]
      })
    }
  }
}
