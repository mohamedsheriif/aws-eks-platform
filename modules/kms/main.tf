resource "aws_kms_key" "this" {
  for_each = var.keys

  description              = each.value.description
  deletion_window_in_days  = each.value.deletion_window_in_days
  enable_key_rotation      = each.value.enable_key_rotation
  customer_master_key_spec = each.value.customer_master_key_spec
  policy                   = each.value.policy
  rotation_period_in_days  = each.value.rotation_period_in_days

  tags = merge({
    Name = format("%s-%s-%s-kms", var.project, var.env, each.key)
  }, var.tags)
}

resource "aws_kms_alias" "this" {
  for_each = var.keys

  name          = "alias/${each.value.name}"
  target_key_id = aws_kms_key.this[each.key].key_id
}
