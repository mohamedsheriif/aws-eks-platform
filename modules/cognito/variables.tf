variable "user_pools" {
  description = "Map of Cognito User Pools"
  type = map(object({
    # (Required) The name of the user pool.
    name = string

    # (Optional) ACTIVE or INACTIVE. Defaults to "ACTIVE".
    deletion_protection = optional(string, "ACTIVE")

    # (Optional) Attributes verified automatically. Defaults to ["email"].
    auto_verified_attributes = optional(list(string), ["email"])

    # (Optional) Attributes users sign in with. Defaults to ["email"].
    username_attributes = optional(list(string), ["email"])

    # (Optional) OFF, OPTIONAL or ON. TOTP is enabled whenever MFA is not OFF. Defaults to "OPTIONAL".
    mfa_configuration = optional(string, "OPTIONAL")

    # (Optional) LITE, ESSENTIALS or PLUS. Defaults to "ESSENTIALS".
    user_pool_tier = optional(string, "ESSENTIALS")

    # (Optional) Threat protection mode (OFF, AUDIT, ENFORCED). Needs the PLUS tier. Defaults to null.
    advanced_security_mode = optional(string)

    # (Optional) Only admins can create users. Defaults to false.
    allow_admin_create_user_only = optional(bool, false)

    # (Optional) Password policy. Defaults to 12 characters with all character classes.
    password_policy = optional(object({
      minimum_length                   = optional(number, 12)
      require_lowercase                = optional(bool, true)
      require_uppercase                = optional(bool, true)
      require_numbers                  = optional(bool, true)
      require_symbols                  = optional(bool, true)
      temporary_password_validity_days = optional(number, 3)
      password_history_size            = optional(number, null)
    }), {})

    # (Optional) Email sending. Use DEVELOPER with an SES identity ARN to send through SES.
    email_configuration = optional(object({
      email_sending_account = optional(string, "COGNITO_DEFAULT")
      source_arn            = optional(string)
      from_email_address    = optional(string)
      configuration_set     = optional(string)
    }), {})

    # (Optional) Custom domain for the hosted UI (e.g. auth.dev.shopflow.example.com). Defaults to null.
    domain = optional(string)

    # (Optional) ACM certificate ARN in us-east-1 for the custom domain. Defaults to null.
    domain_certificate_arn = optional(string)

    # (Optional) Additional tags for the user pool. Defaults to {}.
    tags = optional(map(string), {})
  }))
  default = {}
}

variable "user_pool_clients" {
  description = "Map of Cognito User Pool Clients"
  type = map(object({
    # (Required) Key of the user pool in user_pools.
    user_pool_key = string

    # (Required) The name of the app client.
    name = string

    # (Optional) Token lifetimes: refresh in days, access and ID in minutes.
    refresh_token_validity = optional(number, 30)
    access_token_validity  = optional(number, 60)
    id_token_validity      = optional(number, 60)

    # (Optional) Auth flows the client can use. Defaults to SRP and refresh token.
    explicit_auth_flows = optional(list(string), ["ALLOW_USER_SRP_AUTH", "ALLOW_REFRESH_TOKEN_AUTH"])

    # (Optional) OAuth settings for the hosted UI. Defaults to none.
    allowed_oauth_flows  = optional(list(string), [])
    allowed_oauth_scopes = optional(list(string), [])
    callback_urls        = optional(list(string), [])
    logout_urls          = optional(list(string), [])

    # (Optional) Whether to generate a client secret (server-side clients). Defaults to false.
    generate_secret = optional(bool, false)
  }))
  default = {}
}

variable "project" {
  description = "Project name"
  type        = string
}

variable "env" {
  description = "Environment name"
  type        = string
}

variable "tags" {
  description = "Additional tags for resources"
  type        = map(string)
  default     = {}
}
