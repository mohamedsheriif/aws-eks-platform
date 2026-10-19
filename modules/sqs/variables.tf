variable "queues" {
  description = "Map of SQS queue configurations"
  type = map(object({
    # (Required) The name of the SQS queue.
    name = string

    # (Optional) The number of seconds messages are retained. Defaults to 345600 (4 days).
    message_retention_seconds = optional(number, 345600)

    # (Optional) The time in seconds for long polling. Defaults to 20.
    receive_wait_time_seconds = optional(number, 20)

    # (Optional) The time in seconds a message is invisible after being received. Defaults to 30.
    visibility_timeout_seconds = optional(number, 30)

    # (Optional) KMS key for server-side encryption. Defaults to null (SQS-managed SSE).
    kms_master_key_id = optional(string)

    # (Optional) The ARN of the dead-letter queue. Defaults to null.
    dlq_arn = optional(string, null)

    # (Optional) The maximum number of receive attempts before sending to the DLQ. Defaults to 3.
    max_receive_count = optional(number, 3)

    # (Optional) A queue policy document in JSON format. Defaults to null.
    policy = optional(string, null)
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
