include "root" {
  path = find_in_parent_folders("root.hcl")
}

locals {
  env  = read_terragrunt_config(find_in_parent_folders("env.hcl")).locals
  root = "arn:aws:iam::${local.env.account_id}:root"

  root_statement = {
    Sid       = "EnableIAMPolicies"
    Effect    = "Allow"
    Principal = { AWS = local.root }
    Action    = "kms:*"
    Resource  = "*"
  }
}

terraform {
  source = "${get_repo_root()}/modules/kms"
}

inputs = {
  project = local.env.project
  env     = local.env.env
  tags    = local.env.tags

  keys = {
    eks = {
      name                    = "${local.env.project}-${local.env.env}-eks"
      description             = "EKS Kubernetes secrets envelope encryption"
      deletion_window_in_days = 7
      enable_key_rotation     = true
      rotation_period_in_days = 90
    }

    # Node and PV volumes. EC2 uses the key on behalf of the Auto Scaling
    # service-linked role and the EBS CSI driver.
    ebs = {
      name                    = "${local.env.project}-${local.env.env}-ebs"
      description             = "EBS volumes for EKS nodes and persistent volumes"
      deletion_window_in_days = 7
      enable_key_rotation     = true
      rotation_period_in_days = 90
      policy = jsonencode({
        Version = "2012-10-17"
        Statement = [
          local.root_statement,
          {
            Sid       = "AllowEC2ForAccountPrincipals"
            Effect    = "Allow"
            Principal = { AWS = "*" }
            Action    = ["kms:Encrypt", "kms:Decrypt", "kms:ReEncrypt*", "kms:GenerateDataKey*", "kms:DescribeKey", "kms:CreateGrant"]
            Resource  = "*"
            Condition = {
              StringEquals = {
                "kms:CallerAccount" = local.env.account_id
                "kms:ViaService"    = "ec2.${local.env.region}.amazonaws.com"
              }
            }
          },
        ]
      })
    }

    rds = {
      name                    = "${local.env.project}-${local.env.env}-rds"
      description             = "RDS storage"
      deletion_window_in_days = 7
      enable_key_rotation     = true
      rotation_period_in_days = 90
    }

    elasticache = {
      name                    = "${local.env.project}-${local.env.env}-elasticache"
      description             = "ElastiCache at-rest encryption"
      deletion_window_in_days = 7
      enable_key_rotation     = true
      rotation_period_in_days = 90
    }

    # CloudFront reads the assets bucket through OAC, so it must be able to decrypt.
    s3 = {
      name                    = "${local.env.project}-${local.env.env}-s3"
      description             = "S3 buckets (assets, data, Loki)"
      deletion_window_in_days = 7
      enable_key_rotation     = true
      rotation_period_in_days = 90
      policy = jsonencode({
        Version = "2012-10-17"
        Statement = [
          local.root_statement,
          {
            Sid       = "AllowCloudFrontOAC"
            Effect    = "Allow"
            Principal = { Service = "cloudfront.amazonaws.com" }
            Action    = ["kms:Decrypt"]
            Resource  = "*"
            Condition = {
              StringLike = { "aws:SourceArn" = "arn:aws:cloudfront::${local.env.account_id}:distribution/*" }
            }
          },
        ]
      })
    }

    sqs = {
      name                    = "${local.env.project}-${local.env.env}-sqs"
      description             = "SQS queues"
      deletion_window_in_days = 7
      enable_key_rotation     = true
      rotation_period_in_days = 90
    }

    secrets = {
      name                    = "${local.env.project}-${local.env.env}-secrets"
      description             = "Secrets Manager secrets (RDS master password, Tailscale auth key, service env)"
      deletion_window_in_days = 7
      enable_key_rotation     = true
      rotation_period_in_days = 90
    }
  }
}
