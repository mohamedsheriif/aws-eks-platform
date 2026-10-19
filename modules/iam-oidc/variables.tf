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

variable "oidc_providers" {
  description = "Map of OIDC identity providers to create"
  type = map(object({
    # (Required) OIDC provider URL (e.g. https://token.actions.githubusercontent.com).
    url = string

    # (Required) Allowed audiences (client IDs).
    audiences = list(string)

    # (Optional) TLS certificate thumbprints. Not required for publicly trusted CAs. Defaults to [].
    thumbprint_list = optional(list(string), [])
  }))
  default = {}
}

variable "roles" {
  description = "Map of IAM roles that trust an OIDC provider"
  type = map(object({
    # (Required) The name of the IAM role.
    name = string

    # (Optional) Description of the IAM role. Defaults to "".
    description = optional(string, "")

    # (Required) Key of the oidc_providers entry this role trusts.
    oidc_provider_key = string

    # (Required) The audience value used in the aud condition.
    audience = string

    # (Required) The sub condition values (supports wildcards, e.g. repo:owner/name:ref:refs/heads/main).
    subjects = list(string)

    # (Optional) List of managed policy ARNs to attach. Defaults to [].
    policy_arns = optional(list(string), [])

    # (Optional) Map of inline policy name to policy JSON document. Defaults to {}.
    inline_policies = optional(map(string), {})
  }))
  default = {}
}
