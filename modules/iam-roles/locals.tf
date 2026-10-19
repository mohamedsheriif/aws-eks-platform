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

  assume_role_policies = {
    for role_name, role in var.roles :
    role_name => jsonencode({
      Version = "2012-10-17"
      Statement = [{
        Effect    = "Allow"
        Principal = role.service != null ? tomap({ Service = [role.service] }) : tomap({ AWS = role.trusted_entity })
        Action    = role.assume_role_actions
      }]
    })
  }
}
