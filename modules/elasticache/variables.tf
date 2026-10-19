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

variable "subnet_groups" {
  description = "Configuration map for ElastiCache subnet groups"
  type = map(object({
    # (Required) The name of the subnet group.
    name = string

    # (Required) The list of subnet IDs to include in the subnet group.
    subnet_ids = list(string)
  }))
  default = {}
}

variable "cache" {
  description = "Configuration map for ElastiCache replication groups (cluster mode disabled). Encryption in transit and at rest and IAM authentication are always on."
  type = map(object({
    # (Required) The replication group ID.
    cluster_name = string

    # (Optional) Description of the replication group. Defaults to "".
    description = optional(string, "")

    # (Required) The cache engine (redis or valkey).
    engine = string

    # (Required) The version of the cache engine (e.g., 8.0).
    engine_version = string

    # (Required) The compute and memory capacity of the nodes (e.g., cache.t4g.small).
    node_type = string

    # (Required) The name of the parameter group to use (e.g., default.valkey8).
    parameter_group_name = string

    # (Optional) The port number for the cache cluster. Defaults to 6379.
    port = optional(number, 6379)

    # (Optional) Number of nodes (primary + replicas). Defaults to 1.
    num_cache_clusters = optional(number, 1)

    # (Optional) Whether automatic failover is enabled (needs num_cache_clusters >= 2). Defaults to false.
    automatic_failover_enabled = optional(bool, false)

    # (Optional) Whether to enable Multi-AZ support. Defaults to false.
    multi_az = optional(bool, false)

    # (Optional) The number of days to retain automatic snapshots. Defaults to 0.
    snapshot_retention_limit = optional(number, 0)

    # (Optional) Whether to apply changes immediately. Defaults to true.
    apply_immediately = optional(bool, true)

    # (Optional) The key of the subnet group in var.subnet_groups to use. Defaults to null.
    subnet_group_key_name = optional(string, null)

    # (Optional) Security group IDs to associate with the cluster. Defaults to [].
    security_group_ids = optional(list(string), [])

    # (Optional) KMS key ARN for at-rest encryption. Defaults to null (AWS-managed key).
    kms_key_id = optional(string)

    # (Optional) IAM-authenticated users keyed by user name. Clients connect with an
    # IAM token and need elasticache:Connect on the replication group and the user. Defaults to {}.
    iam_users = optional(map(object({
      # (Required) Redis/Valkey ACL, e.g. "on ~orders:* +@all -@dangerous".
      access_string = string
    })), {})
  }))
  default = {}
}
