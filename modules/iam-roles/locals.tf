locals {
  flattened_policy_attachments = flatten([
    for role_name, role in var.roles : [
      for policy_arn in role.policy_arns : {
        role_name  = role_name
        policy_arn = policy_arn
      }
    ]
  ])

  flattened_inline_policies = flatten([
    for role_name, role in var.roles : [
      for policy_name, policy_doc in role.inline_policies : {
        role_name   = role_name
        policy_name = policy_name
        policy_doc  = policy_doc
      }
    ]
  ])

  pod_identity_assume_role_policy = var.pod_identity_cluster_arn == null ? null : jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = ["pods.eks.amazonaws.com"] }
      Action    = ["sts:AssumeRole", "sts:TagSession"]
      Condition = {
        StringEquals = { "aws:SourceAccount" = split(":", var.pod_identity_cluster_arn)[4] }
        ArnEquals    = { "aws:SourceArn" = var.pod_identity_cluster_arn }
      }
    }]
  })

  assume_role_policies = {
    for role_name, role in var.roles :
    role_name => role.pod_identity ? local.pod_identity_assume_role_policy : jsonencode({
      Version = "2012-10-17"
      Statement = [merge(
        {
          Effect    = "Allow"
          Principal = role.service != null ? tomap({ Service = [role.service] }) : tomap({ AWS = role.trusted_entity })
          Action    = role.assume_role_actions
        },
        { for k, v in { Condition = role.assume_role_conditions } : k => v if length(v) > 0 },
      )]
    })
  }
}
