include "root" {
  path = find_in_parent_folders("root.hcl")
}

locals {
  env = read_terragrunt_config(find_in_parent_folders("env.hcl")).locals
}

terraform {
  source = "${get_repo_root()}/modules/iam-roles"
}

dependency "kms" {
  config_path = "../kms"

  mock_outputs = {
    kms_key_arns = {
      s3  = "arn:aws:kms:us-east-1:111111111111:key/mock-s3"
      sqs = "arn:aws:kms:us-east-1:111111111111:key/mock-sqs"
    }
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan"]
}

# ARNs are built from the fixed resource names, so this unit only depends on kms
# and can be applied before eks, which creates the Pod Identity associations.
inputs = {
  project = local.env.project
  env     = local.env.env
  tags    = local.env.tags

  roles = {
    # Microservices in the apps namespace. Each service account is named after its service.
    # The RDS resource ID is assigned at creation, so rds-db:connect uses dbuser:*/<db user>.

    catalog = {
      name                = "${local.env.project}-${local.env.env}-catalog"
      description         = "apps/catalog"
      service             = "pods.eks.amazonaws.com"
      assume_role_actions = ["sts:AssumeRole", "sts:TagSession"]
      assume_role_conditions = {
        StringEquals = { "aws:SourceAccount" = local.env.account_id }
        ArnEquals    = { "aws:SourceArn" = "arn:aws:eks:${local.env.region}:${local.env.account_id}:cluster/${local.env.project}-${local.env.env}" }
      }
      inline_policies = {
        catalog = jsonencode({
          Version = "2012-10-17"
          Statement = [
            {
              Sid      = "PostgreSQL"
              Effect   = "Allow"
              Action   = "rds-db:connect"
              Resource = "arn:aws:rds-db:${local.env.region}:${local.env.account_id}:dbuser:*/catalog"
            },
            {
              Sid    = "Valkey"
              Effect = "Allow"
              Action = "elasticache:Connect"
              Resource = [
                "arn:aws:elasticache:${local.env.region}:${local.env.account_id}:replicationgroup:${local.env.project}-${local.env.env}-valkey",
                "arn:aws:elasticache:${local.env.region}:${local.env.account_id}:user:catalog",
              ]
            },
            {
              Sid       = "ProductImagesList"
              Effect    = "Allow"
              Action    = "s3:ListBucket"
              Resource  = "arn:aws:s3:::${local.env.project}-${local.env.env}-assets-${local.env.account_id}"
              Condition = { StringLike = { "s3:prefix" = "products/*" } }
            },
            {
              Sid      = "ProductImages"
              Effect   = "Allow"
              Action   = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
              Resource = "arn:aws:s3:::${local.env.project}-${local.env.env}-assets-${local.env.account_id}/products/*"
            },
            {
              Sid       = "S3Encryption"
              Effect    = "Allow"
              Action    = ["kms:Decrypt", "kms:GenerateDataKey"]
              Resource  = dependency.kms.outputs.kms_key_arns["s3"]
              Condition = { StringEquals = { "kms:ViaService" = "s3.${local.env.region}.amazonaws.com" } }
            },
          ]
        })
      }
    }

    users = {
      name                = "${local.env.project}-${local.env.env}-users"
      description         = "apps/users"
      service             = "pods.eks.amazonaws.com"
      assume_role_actions = ["sts:AssumeRole", "sts:TagSession"]
      assume_role_conditions = {
        StringEquals = { "aws:SourceAccount" = local.env.account_id }
        ArnEquals    = { "aws:SourceArn" = "arn:aws:eks:${local.env.region}:${local.env.account_id}:cluster/${local.env.project}-${local.env.env}" }
      }
      inline_policies = {
        users = jsonencode({
          Version = "2012-10-17"
          Statement = [
            {
              Sid      = "PostgreSQL"
              Effect   = "Allow"
              Action   = "rds-db:connect"
              Resource = "arn:aws:rds-db:${local.env.region}:${local.env.account_id}:dbuser:*/users"
            },
            {
              Sid       = "UserFilesList"
              Effect    = "Allow"
              Action    = "s3:ListBucket"
              Resource  = "arn:aws:s3:::${local.env.project}-${local.env.env}-data-${local.env.account_id}"
              Condition = { StringLike = { "s3:prefix" = "users/*" } }
            },
            {
              Sid      = "UserFiles"
              Effect   = "Allow"
              Action   = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
              Resource = "arn:aws:s3:::${local.env.project}-${local.env.env}-data-${local.env.account_id}/users/*"
            },
            {
              Sid       = "S3Encryption"
              Effect    = "Allow"
              Action    = ["kms:Decrypt", "kms:GenerateDataKey"]
              Resource  = dependency.kms.outputs.kms_key_arns["s3"]
              Condition = { StringEquals = { "kms:ViaService" = "s3.${local.env.region}.amazonaws.com" } }
            },
          ]
        })
      }
    }

    orders = {
      name                = "${local.env.project}-${local.env.env}-orders"
      description         = "apps/orders"
      service             = "pods.eks.amazonaws.com"
      assume_role_actions = ["sts:AssumeRole", "sts:TagSession"]
      assume_role_conditions = {
        StringEquals = { "aws:SourceAccount" = local.env.account_id }
        ArnEquals    = { "aws:SourceArn" = "arn:aws:eks:${local.env.region}:${local.env.account_id}:cluster/${local.env.project}-${local.env.env}" }
      }
      inline_policies = {
        orders = jsonencode({
          Version = "2012-10-17"
          Statement = [
            {
              Sid      = "PostgreSQL"
              Effect   = "Allow"
              Action   = "rds-db:connect"
              Resource = "arn:aws:rds-db:${local.env.region}:${local.env.account_id}:dbuser:*/orders"
            },
            {
              Sid    = "Valkey"
              Effect = "Allow"
              Action = "elasticache:Connect"
              Resource = [
                "arn:aws:elasticache:${local.env.region}:${local.env.account_id}:replicationgroup:${local.env.project}-${local.env.env}-valkey",
                "arn:aws:elasticache:${local.env.region}:${local.env.account_id}:user:orders",
              ]
            },
            {
              Sid      = "NotificationEvents"
              Effect   = "Allow"
              Action   = ["sqs:SendMessage", "sqs:GetQueueUrl"]
              Resource = "arn:aws:sqs:${local.env.region}:${local.env.account_id}:${local.env.project}-${local.env.env}-notifications"
            },
            {
              Sid       = "SQSEncryption"
              Effect    = "Allow"
              Action    = ["kms:Decrypt", "kms:GenerateDataKey"]
              Resource  = dependency.kms.outputs.kms_key_arns["sqs"]
              Condition = { StringEquals = { "kms:ViaService" = "sqs.${local.env.region}.amazonaws.com" } }
            },
          ]
        })
      }
    }

    # Payment provider API keys come from Secrets Manager through ESO, not from this role.
    payments = {
      name                = "${local.env.project}-${local.env.env}-payments"
      description         = "apps/payments"
      service             = "pods.eks.amazonaws.com"
      assume_role_actions = ["sts:AssumeRole", "sts:TagSession"]
      assume_role_conditions = {
        StringEquals = { "aws:SourceAccount" = local.env.account_id }
        ArnEquals    = { "aws:SourceArn" = "arn:aws:eks:${local.env.region}:${local.env.account_id}:cluster/${local.env.project}-${local.env.env}" }
      }
      inline_policies = {
        payments = jsonencode({
          Version = "2012-10-17"
          Statement = [
            {
              Sid      = "PostgreSQL"
              Effect   = "Allow"
              Action   = "rds-db:connect"
              Resource = "arn:aws:rds-db:${local.env.region}:${local.env.account_id}:dbuser:*/payments"
            },
            {
              Sid      = "NotificationEvents"
              Effect   = "Allow"
              Action   = ["sqs:SendMessage", "sqs:GetQueueUrl"]
              Resource = "arn:aws:sqs:${local.env.region}:${local.env.account_id}:${local.env.project}-${local.env.env}-notifications"
            },
            {
              Sid       = "SQSEncryption"
              Effect    = "Allow"
              Action    = ["kms:Decrypt", "kms:GenerateDataKey"]
              Resource  = dependency.kms.outputs.kms_key_arns["sqs"]
              Condition = { StringEquals = { "kms:ViaService" = "sqs.${local.env.region}.amazonaws.com" } }
            },
          ]
        })
      }
    }

    notifications = {
      name                = "${local.env.project}-${local.env.env}-notifications"
      description         = "apps/notifications"
      service             = "pods.eks.amazonaws.com"
      assume_role_actions = ["sts:AssumeRole", "sts:TagSession"]
      assume_role_conditions = {
        StringEquals = { "aws:SourceAccount" = local.env.account_id }
        ArnEquals    = { "aws:SourceArn" = "arn:aws:eks:${local.env.region}:${local.env.account_id}:cluster/${local.env.project}-${local.env.env}" }
      }
      inline_policies = {
        notifications = jsonencode({
          Version = "2012-10-17"
          Statement = [
            {
              Sid    = "NotificationEvents"
              Effect = "Allow"
              Action = [
                "sqs:ReceiveMessage",
                "sqs:DeleteMessage",
                "sqs:ChangeMessageVisibility",
                "sqs:GetQueueAttributes",
                "sqs:GetQueueUrl",
              ]
              Resource = "arn:aws:sqs:${local.env.region}:${local.env.account_id}:${local.env.project}-${local.env.env}-notifications"
            },
            {
              Sid       = "SQSEncryption"
              Effect    = "Allow"
              Action    = "kms:Decrypt"
              Resource  = dependency.kms.outputs.kms_key_arns["sqs"]
              Condition = { StringEquals = { "kms:ViaService" = "sqs.${local.env.region}.amazonaws.com" } }
            },
            {
              Sid    = "SendEmail"
              Effect = "Allow"
              Action = ["ses:SendEmail", "ses:SendRawEmail"]
              Resource = [
                "arn:aws:ses:${local.env.region}:${local.env.account_id}:identity/${local.env.domain}",
                "arn:aws:ses:${local.env.region}:${local.env.account_id}:configuration-set/${local.env.project}-${local.env.env}",
              ]
            },
          ]
        })
      }
    }
  }
}
