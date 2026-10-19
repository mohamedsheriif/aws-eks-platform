resource "aws_cognito_user_pool" "this" {
  for_each = var.user_pools

  name                     = each.value.name
  deletion_protection      = each.value.deletion_protection
  auto_verified_attributes = each.value.auto_verified_attributes
  username_attributes      = each.value.username_attributes
  mfa_configuration        = each.value.mfa_configuration
  user_pool_tier           = each.value.user_pool_tier

  dynamic "software_token_mfa_configuration" {
    for_each = each.value.mfa_configuration != "OFF" ? [1] : []
    content {
      enabled = true
    }
  }

  username_configuration {
    case_sensitive = false
  }

  password_policy {
    minimum_length                   = each.value.password_policy.minimum_length
    require_lowercase                = each.value.password_policy.require_lowercase
    require_uppercase                = each.value.password_policy.require_uppercase
    require_numbers                  = each.value.password_policy.require_numbers
    require_symbols                  = each.value.password_policy.require_symbols
    temporary_password_validity_days = each.value.password_policy.temporary_password_validity_days
    password_history_size            = each.value.password_policy.password_history_size
  }

  email_configuration {
    email_sending_account = each.value.email_configuration.email_sending_account
    source_arn            = each.value.email_configuration.source_arn
    from_email_address    = each.value.email_configuration.from_email_address
    configuration_set     = each.value.email_configuration.configuration_set
  }

  admin_create_user_config {
    allow_admin_create_user_only = each.value.allow_admin_create_user_only
  }

  account_recovery_setting {
    recovery_mechanism {
      name     = "verified_email"
      priority = 1
    }
  }

  dynamic "user_pool_add_ons" {
    for_each = each.value.advanced_security_mode != null ? [each.value.advanced_security_mode] : []
    content {
      advanced_security_mode = user_pool_add_ons.value
    }
  }

  tags = merge(each.value.tags, var.tags)
}

resource "aws_cognito_user_pool_client" "this" {
  for_each = var.user_pool_clients

  name         = each.value.name
  user_pool_id = aws_cognito_user_pool.this[each.value.user_pool_key].id

  refresh_token_validity = each.value.refresh_token_validity
  access_token_validity  = each.value.access_token_validity
  id_token_validity      = each.value.id_token_validity

  token_validity_units {
    access_token  = "minutes"
    id_token      = "minutes"
    refresh_token = "days"
  }

  explicit_auth_flows = each.value.explicit_auth_flows

  allowed_oauth_flows                  = each.value.allowed_oauth_flows
  allowed_oauth_scopes                 = each.value.allowed_oauth_scopes
  allowed_oauth_flows_user_pool_client = length(each.value.allowed_oauth_flows) > 0
  callback_urls                        = each.value.callback_urls
  logout_urls                          = each.value.logout_urls
  supported_identity_providers         = ["COGNITO"]

  generate_secret               = each.value.generate_secret
  prevent_user_existence_errors = "ENABLED"
  enable_token_revocation       = true

  lifecycle {
    ignore_changes = [generate_secret]
  }
}

resource "aws_cognito_user_pool_domain" "this" {
  for_each = { for k, v in var.user_pools : k => v if v.domain != null }

  domain          = each.value.domain
  user_pool_id    = aws_cognito_user_pool.this[each.key].id
  certificate_arn = each.value.domain_certificate_arn
}
