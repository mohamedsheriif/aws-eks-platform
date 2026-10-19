variable "project" {
  description = "Project name prefix"
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

variable "acm" {
  description = "Map of DNS-validated ACM certificates"
  type = map(object({
    # (Required) The fully qualified domain name (FQDN) to be protected by the certificate.
    domain_name = string

    # (Optional) A list of domains that should be SANs in the issued certificate. Defaults to [].
    subject_alternative_names = optional(list(string), [])

    # (Required) Route 53 hosted zone the validation records are published into.
    route53_zone_id = string
  }))
  default = {}
}
