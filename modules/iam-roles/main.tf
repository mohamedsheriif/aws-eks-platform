resource "aws_iam_role" "this" {
  for_each = var.roles

  name               = each.value.name
  description        = each.value.description
  assume_role_policy = local.assume_role_policies[each.key]

  tags = merge({
    Name = format("%s-%s-%s-role", var.project, var.env, each.key)
  }, var.tags)
}

resource "aws_iam_role_policy_attachment" "this" {
  for_each = {
    for item in local.flattened_policy_attachments :
    "${item.role_name}-${replace(item.policy_arn, "/[:/.]/", "-")}" => item
  }

  role       = aws_iam_role.this[each.value.role_name].name
  policy_arn = each.value.policy_arn
}

resource "aws_iam_instance_profile" "this" {
  for_each = { for k, v in var.roles : k => v if v.create_instance_profile }

  name = each.value.name
  role = aws_iam_role.this[each.key].name

  tags = var.tags
}

resource "aws_iam_role_policy" "this" {
  for_each = {
    for item in local.flattened_inline_policies :
    "${item.role_name}-${item.policy_name}" => item
  }

  name   = each.value.policy_name
  role   = aws_iam_role.this[each.value.role_name].name
  policy = each.value.policy_doc
}
