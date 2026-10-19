resource "aws_sesv2_email_identity" "this" {
  for_each = var.ses_identities

  email_identity         = each.value.email_identity
  configuration_set_name = each.value.configuration_set_name

  depends_on = [aws_sesv2_configuration_set.this]
}

resource "aws_sesv2_email_identity_mail_from_attributes" "this" {
  for_each = { for k, v in var.ses_identities : k => v if v.mail_from_domain != null }

  email_identity         = aws_sesv2_email_identity.this[each.key].email_identity
  mail_from_domain       = each.value.mail_from_domain
  behavior_on_mx_failure = "USE_DEFAULT_VALUE"
}

resource "aws_sesv2_configuration_set" "this" {
  for_each = var.ses_configuration_sets

  configuration_set_name = each.value.name

  reputation_options {
    reputation_metrics_enabled = each.value.reputation_metrics_enabled
  }

  sending_options {
    sending_enabled = each.value.sending_enabled
  }
}
