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

variable "subnet_ids" {
  description = "Map of subnet keys to their subnet IDs"
  type        = map(string)
}

variable "subnet_groups" {
  description = "Map of RDS subnet group configurations"
  type = map(object({
    # (Required) The name of the subnet group.
    name = string

    # (Optional) A description for the subnet group. Defaults to null.
    description = optional(string)

    # (Required) The subnet keys from the subnet_ids map to include in the group.
    subnet_keys = list(string)
  }))
  default = {}
}

variable "rds" {
  description = "Map of RDS instance configurations. Storage is always encrypted and the master password is managed by RDS."
  type = map(object({
    # (Required) The DB instance identifier.
    identifier = string

    # (Required) The database engine (e.g., postgres).
    engine = string

    # (Required) The engine version (e.g., 17).
    engine_version = string

    # (Required) The instance class (e.g., db.t4g.medium).
    instance_class = string

    # (Optional) The name of the database to create. Defaults to null.
    db_name = optional(string, null)

    # (Required) The master username for the database.
    username = string

    # (Optional) The key of the parameter group in var.parameters to use. Defaults to null.
    parameter_group_key_name = optional(string, null)

    # (Required) The allocated storage in GiB.
    allocated_storage = number

    # (Optional) The ARN of the KMS key for storage encryption. Defaults to null (aws/rds).
    kms_key_id = optional(string, null)

    # (Optional) KMS key for the master user secret. Defaults to null (aws/secretsmanager).
    master_user_secret_kms_key_id = optional(string)

    # (Optional) The storage type (gp2, gp3, io1). Defaults to "gp3".
    storage_type = optional(string, "gp3")

    # (Optional) The upper limit in GiB for autoscaling storage. Defaults to 0 (disabled).
    max_allocated_storage = optional(number, 0)

    # (Optional) Whether to enable IAM database authentication. Defaults to true.
    iam_database_authentication_enabled = optional(bool, true)

    # (Optional) A list of VPC security group IDs to associate. Defaults to null.
    vpc_security_group_ids = optional(list(string))

    # (Optional) The key of the subnet group in var.subnet_groups to use. Defaults to null.
    db_subnet_group_key_name = optional(string, null)

    # (Required) Whether to enable Multi-AZ deployment.
    multi_az = bool

    # (Required) The number of days to retain automated backups.
    backup_retention_period = number

    # (Optional) Whether to skip the final snapshot on deletion. Defaults to false.
    skip_final_snapshot = optional(bool, false)

    # (Required) Whether to enable deletion protection.
    deletion_protection = bool

    # (Optional) Whether to apply changes immediately. Defaults to true.
    apply_immediately = optional(bool, true)

    # (Optional) Whether to automatically upgrade minor engine versions. Defaults to true.
    auto_minor_version_upgrade = optional(bool, true)

    # (Optional) Whether to allow major version upgrades. Defaults to false.
    allow_major_version_upgrade = optional(bool, false)

    # (Optional) Whether to copy tags to snapshots. Defaults to true.
    copy_tags_to_snapshot = optional(bool, true)

    # (Optional) Log types to export to CloudWatch. Defaults to [].
    enabled_cloudwatch_logs_exports = optional(set(string), [])

    # (Optional) The number of days to retain CloudWatch log exports. Defaults to 7.
    cloudwatch_logs_retention_days = optional(number, 7)

    # (Optional) KMS key ARN that encrypts those log groups. Defaults to null.
    cloudwatch_logs_kms_key_id = optional(string)

    # (Optional) Whether to enable Performance Insights. Defaults to false.
    performance_insights_enabled = optional(bool, false)
  }))

  default = {}
}

variable "parameters" {
  description = "Map of DB parameter group configurations"
  type = map(object({
    # (Required) The name of the DB parameter group.
    name = string

    # (Required) The DB parameter group family (e.g., postgres17).
    family = string

    # (Required) List of parameters to apply to the parameter group.
    parameter = list(object({
      # (Required) The name of the parameter.
      name = string

      # (Required) The value of the parameter.
      value = string

      # (Optional) "immediate" or "pending-reboot". Static parameters such as
      # rds.force_ssl only accept "pending-reboot". Defaults to "pending-reboot".
      apply_method = optional(string, "pending-reboot")
    }))
  }))
  default = {}
}
