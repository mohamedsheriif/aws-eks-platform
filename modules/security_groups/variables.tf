variable "vpc_id" {
  description = "The VPC ID where security groups will be created"
  type        = string
}

variable "env" {
  description = "Environment name"
  type        = string
}

variable "project" {
  description = "Project name prefix"
  type        = string
}

variable "tags" {
  description = "Additional tags for resources"
  type        = map(string)
  default     = {}
}

variable "security_groups" {
  description = "Map of security groups to create with optional ingress/egress rules"
  type = map(object({
    # (Required) The name of the security group.
    name = string

    # (Optional) A description for the security group. Defaults to null.
    description = optional(string)

    # (Optional) List of ingress rules. Defaults to [].
    ingress_rules = optional(list(object({
      # (Optional) A description for the ingress rule. Defaults to null.
      description = optional(string)

      # (Required) The start of the port range.
      from_port = number

      # (Required) The end of the port range.
      to_port = number

      # (Required) The IP protocol (tcp, udp, icmp, or -1 for all).
      protocol = string

      # (Optional) List of source CIDR blocks. Defaults to null.
      cidr_blocks = optional(list(string))

      # (Optional) List of source security group IDs. Defaults to null.
      security_groups = optional(list(string))

      # (Optional) Keys of other security groups in this same map to allow traffic from.
      source_security_group_keys = optional(list(string))

      # (Optional) Whether to allow traffic from the security group itself. Defaults to false.
      self = optional(bool, false)
    })), [])

    # (Optional) List of egress rules. Defaults to [].
    egress_rules = optional(list(object({
      # (Optional) A description for the egress rule. Defaults to null.
      description = optional(string)

      # (Required) The start of the port range.
      from_port = number

      # (Required) The end of the port range.
      to_port = number

      # (Required) The IP protocol (tcp, udp, icmp, or -1 for all).
      protocol = string

      # (Optional) List of destination CIDR blocks. Defaults to null.
      cidr_blocks = optional(list(string))

      # (Optional) List of destination security group IDs. Defaults to null.
      security_groups = optional(list(string))

      # (Optional) Keys of other security groups in this same map to allow traffic to.
      destination_security_group_keys = optional(list(string))
    })), [])

    # (Optional) Additional tags for this security group. Defaults to null.
    tags = optional(map(string))
  }))
  default = {}
}
