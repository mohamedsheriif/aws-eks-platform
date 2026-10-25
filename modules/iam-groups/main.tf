locals {
  flattened_policy_attachments = flatten([
    for group_key, group in var.groups : [
      for policy_arn in group.policy_arns : {
        group_key  = group_key
        policy_arn = policy_arn
      }
    ]
  ])

  flattened_inline_policies = flatten([
    for group_key, group in var.groups : [
      for policy_name, policy_doc in group.inline_policies : {
        group_key   = group_key
        policy_name = policy_name
        policy_doc  = policy_doc
      }
    ]
  ])
}

resource "aws_iam_group" "this" {
  for_each = var.groups

  name = each.value.name
  path = each.value.path
}

resource "aws_iam_group_policy_attachment" "this" {
  for_each = {
    for item in local.flattened_policy_attachments :
    "${item.group_key}-${replace(item.policy_arn, "/[:/.]/", "-")}" => item
  }

  group      = aws_iam_group.this[each.value.group_key].name
  policy_arn = each.value.policy_arn
}

resource "aws_iam_group_policy" "this" {
  for_each = {
    for item in local.flattened_inline_policies :
    "${item.group_key}-${item.policy_name}" => item
  }

  name   = each.value.policy_name
  group  = aws_iam_group.this[each.value.group_key].name
  policy = each.value.policy_doc
}

resource "aws_iam_group_membership" "this" {
  for_each = { for k, v in var.groups : k => v if length(v.users) > 0 }

  name  = "${each.value.name}-membership"
  group = aws_iam_group.this[each.key].name
  users = each.value.users
}
