variable "groups" {
  description = "Map of IAM groups to create"
  type = map(object({
    # (Required) The name of the IAM group.
    name = string

    # (Optional) The path for the group. Defaults to "/".
    path = optional(string, "/")

    # (Optional) List of managed policy ARNs to attach. Defaults to [].
    policy_arns = optional(list(string), [])

    # (Optional) Map of inline policy name to policy JSON document. Defaults to {}.
    inline_policies = optional(map(string), {})

    # (Optional) IAM user names that belong to the group. Membership is managed
    # exclusively here when the list is not empty. Defaults to [].
    users = optional(list(string), [])
  }))
  default = {}
}
