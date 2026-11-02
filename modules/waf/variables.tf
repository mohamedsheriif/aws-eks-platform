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

variable "web_acls" {
  description = "Map of WAFv2 web ACLs that allow traffic unless a rule blocks it"
  type = map(object({
    # (Required) The name of the web ACL.
    name = string

    # (Required) "CLOUDFRONT" (must be created in us-east-1) or "REGIONAL" (ALB, API Gateway).
    scope = string

    # (Optional) AWS managed rule groups, evaluated in list order, e.g.
    # ["AWSManagedRulesCommonRuleSet", "AWSManagedRulesKnownBadInputsRuleSet"]. Defaults to [].
    managed_rule_groups = optional(list(string), [])

    # (Optional) Block an IP that sends more than this many requests in 5 minutes.
    # Evaluated after the managed rule groups. Defaults to null (no rate limit).
    rate_limit = optional(number)
  }))
  default = {}

  validation {
    condition     = alltrue([for acl in values(var.web_acls) : contains(["CLOUDFRONT", "REGIONAL"], acl.scope)])
    error_message = "scope must be CLOUDFRONT or REGIONAL."
  }
}
