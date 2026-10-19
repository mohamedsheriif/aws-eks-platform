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

variable "secrets" {
  description = "Map of Secrets Manager secret configurations"
  type = map(object({
    # (Required) The name of the secret.
    name = string

    # (Optional) A description of the secret's purpose. Defaults to null.
    description = optional(string)

    # (Optional) Seed the secret with a random 32-character value. When false the
    # secret is created empty and filled outside Terraform. Defaults to false.
    use_random_secret = optional(bool, false)

    # (Optional) The number of days before the secret can be permanently deleted. Defaults to 7.
    recovery_window_in_days = optional(number, 7)

    # (Optional) KMS key ARN used to encrypt the secret. Defaults to aws/secretsmanager.
    kms_key_id = optional(string)
  }))
  default = {}
}
