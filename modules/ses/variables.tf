variable "ses_identities" {
  description = "Map of SES identities (domains or email addresses)"
  type = map(object({
    # (Required) The email address or domain to verify as an SES identity.
    email_identity = string

    # (Optional) The custom MAIL FROM domain. Defaults to null.
    mail_from_domain = optional(string)

    # (Optional) The name of the configuration set to associate. Defaults to null.
    configuration_set_name = optional(string, null)

    # (Optional) Route 53 zone to publish the three Easy DKIM CNAME records into. Defaults to null.
    route53_zone_id = optional(string, null)
  }))
  default = {}
}

variable "ses_configuration_sets" {
  description = "Map of SES configuration sets"
  type = map(object({
    # (Required) The name of the configuration set.
    name = string

    # (Optional) Whether reputation metrics are enabled. Defaults to false.
    reputation_metrics_enabled = optional(bool, false)

    # (Optional) Whether email sending is enabled for the configuration set. Defaults to true.
    sending_enabled = optional(bool, true)
  }))
  default = {}
}
