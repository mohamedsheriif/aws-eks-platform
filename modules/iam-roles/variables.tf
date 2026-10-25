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

variable "pod_identity_cluster_arn" {
  description = "EKS cluster ARN that roles with pod_identity = true trust. Required when any role sets it."
  type        = string
  default     = null
}

variable "roles" {
  description = "Map of IAM roles to create"
  type = map(object({
    # (Required) The name of the IAM role.
    name = string

    # (Optional) Description of the IAM role. Defaults to "".
    description = optional(string, "")

    # (Optional) Trust EKS Pod Identity (pods.eks.amazonaws.com, sts:AssumeRole + sts:TagSession),
    # limited to var.pod_identity_cluster_arn and its account. Replaces service, trusted_entity,
    # assume_role_actions and assume_role_conditions. Defaults to false.
    pod_identity = optional(bool, false)

    # (Optional) AWS service principal allowed to assume the role (e.g. ec2.amazonaws.com).
    service = optional(string, null)

    # (Optional) AWS principal ARNs allowed to assume the role. Used when service is null.
    trusted_entity = optional(list(string), null)

    # (Optional) Actions allowed in the trust policy. Defaults to ["sts:AssumeRole"].
    assume_role_actions = optional(list(string), ["sts:AssumeRole"])

    # (Optional) Trust policy conditions, operator => { key => value }, e.g.
    # { StringEquals = { "aws:SourceAccount" = "111111111111" } }. Defaults to {} (none).
    assume_role_conditions = optional(map(map(string)), {})

    # (Optional) List of managed policy ARNs to attach. Defaults to [].
    policy_arns = optional(list(string), [])

    # (Optional) Map of inline policy name to policy JSON document. Defaults to {}.
    inline_policies = optional(map(string), {})

    # (Optional) Whether to create an EC2 instance profile for the role. Defaults to false.
    create_instance_profile = optional(bool, false)
  }))

  validation {
    condition     = alltrue([for r in values(var.roles) : r.pod_identity != (r.service != null || r.trusted_entity != null)])
    error_message = "Each role needs exactly one of pod_identity, service or trusted_entity."
  }

  validation {
    condition     = alltrue([for r in values(var.roles) : !r.pod_identity || var.pod_identity_cluster_arn != null])
    error_message = "Roles with pod_identity = true need pod_identity_cluster_arn."
  }
}
