include "root" {
  path = find_in_parent_folders("root.hcl")
}

locals {
  env = read_terragrunt_config(find_in_parent_folders("env.hcl")).locals
}

terraform {
  source = "${get_repo_root()}/modules/sqs"
}

dependency "kms" {
  config_path = "../kms"

  mock_outputs = {
    kms_key_arns = { sqs = "arn:aws:kms:us-east-1:111111111111:key/mock-sqs" }
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan"]
}

inputs = {
  project = local.env.project
  env     = local.env.env
  tags    = local.env.tags

  # Events from orders and payments, consumed by notifications. Access is granted by the
  # services' Pod Identity roles; the queue policy only enforces TLS.
  queues = {
    notifications = {
      name                       = "${local.env.project}-${local.env.env}-notifications"
      kms_master_key_id          = dependency.kms.outputs.kms_key_arns["sqs"]
      visibility_timeout_seconds = 60
      dead_letter_queue          = { max_receive_count = 5 }

      policy = jsonencode({
        Version = "2012-10-17"
        Statement = [{
          Sid       = "DenyInsecureTransport"
          Effect    = "Deny"
          Principal = "*"
          Action    = "sqs:*"
          Resource  = "arn:aws:sqs:${local.env.region}:${local.env.account_id}:${local.env.project}-${local.env.env}-notifications"
          Condition = { Bool = { "aws:SecureTransport" = "false" } }
        }]
      })
    }
  }
}
