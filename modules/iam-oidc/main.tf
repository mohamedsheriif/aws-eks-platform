resource "aws_iam_openid_connect_provider" "this" {
  for_each = var.oidc_providers

  url             = each.value.url
  client_id_list  = each.value.audiences
  thumbprint_list = each.value.thumbprint_list

  tags = merge({
    Name = format("%s-%s-%s-oidc-provider", var.project, var.env, each.key)
  }, var.tags)

  lifecycle {
    ignore_changes = [thumbprint_list]
  }
}

resource "aws_iam_role" "this" {
  for_each = var.roles

  name        = each.value.name
  description = each.value.description

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Federated = aws_iam_openid_connect_provider.this[each.value.oidc_provider_key].arn
      }
      Action = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "${local.provider_host[each.value.oidc_provider_key]}:aud" = each.value.audience
        }
        StringLike = {
          "${local.provider_host[each.value.oidc_provider_key]}:sub" = each.value.subjects
        }
      }
    }]
  })

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

resource "aws_iam_role_policy" "this" {
  for_each = {
    for item in local.flattened_inline_policies :
    "${item.role_name}-${item.policy_name}" => item
  }

  name   = each.value.policy_name
  role   = aws_iam_role.this[each.value.role_name].name
  policy = each.value.policy_doc
}
