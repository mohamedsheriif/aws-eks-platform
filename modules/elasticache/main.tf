locals {
  iam_users = merge([
    for ck, c in var.cache : {
      for user_name, u in c.iam_users : "${ck}/${user_name}" => {
        cache_key     = ck
        user_name     = user_name
        engine        = c.engine
        access_string = u.access_string
      }
    }
  ]...)
}

resource "aws_elasticache_subnet_group" "this" {
  for_each = var.subnet_groups

  name       = each.value.name
  subnet_ids = each.value.subnet_ids
}

# Every user group must contain a user named "default"; this one is disabled.
resource "aws_elasticache_user" "default" {
  for_each = var.cache

  user_id       = "${each.value.cluster_name}-default"
  user_name     = "default"
  engine        = each.value.engine
  access_string = "off -@all"

  authentication_mode {
    type = "no-password-required"
  }

  tags = var.tags
}

# IAM authentication requires user_id to equal user_name.
resource "aws_elasticache_user" "iam" {
  for_each = local.iam_users

  user_id       = each.value.user_name
  user_name     = each.value.user_name
  engine        = each.value.engine
  access_string = each.value.access_string

  authentication_mode {
    type = "iam"
  }

  tags = var.tags
}

resource "aws_elasticache_user_group" "this" {
  for_each = var.cache

  user_group_id = "${each.value.cluster_name}-users"
  engine        = each.value.engine
  user_ids = concat(
    [aws_elasticache_user.default[each.key].user_id],
    [for k, u in aws_elasticache_user.iam : u.user_id if local.iam_users[k].cache_key == each.key]
  )

  tags = var.tags
}

resource "aws_elasticache_replication_group" "this" {
  for_each = var.cache

  replication_group_id = each.value.cluster_name
  description          = each.value.description

  engine                     = each.value.engine
  engine_version             = each.value.engine_version
  node_type                  = each.value.node_type
  port                       = each.value.port
  parameter_group_name       = each.value.parameter_group_name
  num_cache_clusters         = each.value.num_cache_clusters
  automatic_failover_enabled = each.value.automatic_failover_enabled
  multi_az_enabled           = each.value.multi_az
  snapshot_retention_limit   = each.value.snapshot_retention_limit
  apply_immediately          = each.value.apply_immediately

  subnet_group_name = (
    each.value.subnet_group_key_name != null
    ? aws_elasticache_subnet_group.this[each.value.subnet_group_key_name].name
    : null
  )
  security_group_ids = each.value.security_group_ids

  user_group_ids             = [aws_elasticache_user_group.this[each.key].user_group_id]
  transit_encryption_enabled = true
  transit_encryption_mode    = "required"
  at_rest_encryption_enabled = true
  kms_key_id                 = each.value.kms_key_id

  tags = var.tags
}
