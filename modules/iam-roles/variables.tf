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

variable "roles" {
  description = "Map of IAM roles to create"
  type = map(object({
    # (Required) The name of the IAM role.
    name = string

    # (Optional) Description of the IAM role. Defaults to "".
    description = optional(string, "")

    # (Optional) AWS service principal allowed to assume the role (e.g. ec2.amazonaws.com).
    service = optional(string, null)

    # (Optional) AWS principal ARNs allowed to assume the role. Used when service is null.
    trusted_entity = optional(list(string), null)

    # (Optional) Actions allowed in the trust policy. EKS Pod Identity roles
    # (pods.eks.amazonaws.com) also need "sts:TagSession". Defaults to ["sts:AssumeRole"].
    assume_role_actions = optional(list(string), ["sts:AssumeRole"])

    # (Optional) List of managed policy ARNs to attach. Defaults to [].
    policy_arns = optional(list(string), [])

    # (Optional) Map of inline policy name to policy JSON document. Defaults to {}.
    inline_policies = optional(map(string), {})

    # (Optional) Whether to create an EC2 instance profile for the role. Defaults to false.
    create_instance_profile = optional(bool, false)
  }))

  validation {
    condition     = alltrue([for r in values(var.roles) : r.service != null || r.trusted_entity != null])
    error_message = "Each role needs either service or trusted_entity."
  }
}
