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

variable "rules" {
  description = "Map of EventBridge rules, each forwarding matching events unchanged to one target"
  type = map(object({
    # (Required) The name of the EventBridge rule.
    name = string

    # (Optional) A description of the rule. Defaults to "".
    description = optional(string, "")

    # (Required) The event pattern as a JSON string.
    event_pattern = string

    # (Required) The ARN of the target (e.g. an SQS queue). Its resource policy must allow events.amazonaws.com.
    target_arn = string
  }))
  default = {}
}
