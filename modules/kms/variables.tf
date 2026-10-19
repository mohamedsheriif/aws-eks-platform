variable "keys" {
  description = "Map of KMS key configurations"
  type = map(object({
    # (Required) The alias name for the KMS key (without the alias/ prefix).
    name = string

    # (Required) A description of the key's purpose.
    description = string

    # (Required) The number of days before key deletion (7–30).
    deletion_window_in_days = number

    # (Required) Whether automatic key rotation is enabled.
    enable_key_rotation = bool

    # (Optional) The type of key material. Defaults to "SYMMETRIC_DEFAULT".
    customer_master_key_spec = optional(string, "SYMMETRIC_DEFAULT")

    # (Optional) A key policy document in JSON format. Defaults to null (account root only).
    policy = optional(string, null)

    # (Optional) The rotation period in days (between 90 and 2560). Defaults to null.
    rotation_period_in_days = optional(number, null)
  }))
  default = {}
}

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
