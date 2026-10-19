resource "aws_secretsmanager_secret" "this" {
  for_each = var.secrets

  name                    = each.value.name
  description             = each.value.description
  recovery_window_in_days = each.value.recovery_window_in_days
  kms_key_id              = each.value.kms_key_id

  tags = merge(
    { Name = format("%s-%s-%s-secret", var.project, var.env, each.key) },
    var.tags
  )
}

# Seed value written once at creation; later changes are made outside Terraform.
resource "aws_secretsmanager_secret_version" "this" {
  for_each = { for k, v in var.secrets : k => v if v.use_random_secret }

  secret_id     = aws_secretsmanager_secret.this[each.key].id
  secret_string = random_password.this[each.key].result

  lifecycle {
    ignore_changes = [secret_string]
  }
}

resource "random_password" "this" {
  for_each = { for k, v in var.secrets : k => v if v.use_random_secret }

  length  = 32
  special = false
}
