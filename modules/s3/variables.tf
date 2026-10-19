variable "buckets" {
  description = "Map of S3 bucket configurations. All buckets block public access."
  type = map(object({
    # (Required) The name of the S3 bucket.
    name = string

    # (Optional) Whether to force deletion of all objects when destroying the bucket. Defaults to false.
    force_destroy = optional(bool, false)

    # (Optional) Whether to enable versioning on the bucket. Defaults to false.
    versioning_enabled = optional(bool, false)

    # (Optional) The SSE algorithm (AES256 or aws:kms). Defaults to "AES256".
    sse_algorithm = optional(string, "AES256")

    # (Optional) The ARN of the KMS key for SSE-KMS encryption. Defaults to null.
    kms_master_key_id = optional(string, null)

    # (Optional) Whether to enable S3 bucket key for SSE-KMS. Defaults to false.
    bucket_key_enabled = optional(bool, false)

    # (Optional) Encryption types the bucket refuses on write. Defaults to ["SSE-C"].
    blocked_encryption_types = optional(list(string), ["SSE-C"])

    # (Optional) Whether to enable server access logging. Defaults to false.
    enable_logging = optional(bool, false)

    # (Optional) The target bucket for access logs. Defaults to "".
    target_bucket = optional(string, "")

    # (Optional) The prefix for access log object keys. Defaults to "<bucket>/logs/".
    target_prefix = optional(string, "")

    # (Optional) Whether to enable lifecycle rules. Defaults to false.
    lifecycle_enabled = optional(bool, false)

    # (Optional) The ID for the lifecycle rule. Defaults to "default-rule".
    lifecycle_rule_id = optional(string, "default-rule")

    # (Optional) The status of the lifecycle rule (Enabled or Disabled). Defaults to "Enabled".
    lifecycle_rule_status = optional(string, "Enabled")

    # (Optional) The object key prefix for the lifecycle rule. Defaults to "".
    lifecycle_prefix = optional(string, "")

    # (Optional) Days after which noncurrent versions are deleted. Defaults to null.
    noncurrent_days = optional(number, null)

    # (Optional) Storage class transitions, e.g. [{ days = 30, storage_class = "STANDARD_IA" },
    # { days = 90, storage_class = "GLACIER_IR" }]. Defaults to [].
    transitions = optional(list(object({
      days          = number
      storage_class = string
    })), [])

    # (Optional) Days after which objects are deleted. Defaults to null.
    expiration_days = optional(number, null)

    # (Optional) A bucket policy document in JSON format. Defaults to null.
    bucket_policy = optional(string, null)

    # (Optional) Whether to enable S3 Object Lock. Defaults to false.
    object_lock_enabled = optional(bool, false)

    # (Optional) Object Lock default retention, used when object_lock_enabled is true.
    object_lock_rule = optional(object({
      # (Optional) The Object Lock retention mode (COMPLIANCE or GOVERNANCE). Defaults to null.
      default_retention_mode = optional(string, null)

      # (Optional) The default retention period in days. Defaults to null.
      default_retention_days = optional(number, null)
    }), {})

    # (Optional) Additional tags specific to this bucket. Defaults to {}.
    tags = optional(map(string), {})
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
