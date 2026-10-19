resource "aws_cloudwatch_log_group" "rds" {
  for_each = local.rds_log_groups

  name              = each.value.name
  retention_in_days = each.value.retention_in_days
  kms_key_id        = each.value.kms_key_id

  tags = var.tags
}

resource "aws_db_instance" "main" {
  for_each = var.rds

  identifier     = each.value.identifier
  engine         = each.value.engine
  engine_version = each.value.engine_version
  db_name        = each.value.db_name
  instance_class = each.value.instance_class
  parameter_group_name = (
    each.value.parameter_group_key_name != null
    ? aws_db_parameter_group.this[each.value.parameter_group_key_name].name
    : null
  )

  allocated_storage     = each.value.allocated_storage
  storage_type          = each.value.storage_type
  storage_encrypted     = true
  kms_key_id            = each.value.kms_key_id
  max_allocated_storage = each.value.max_allocated_storage

  # RDS generates the master password and keeps it in Secrets Manager, so it never lands in state.
  username                            = each.value.username
  manage_master_user_password         = true
  master_user_secret_kms_key_id       = each.value.master_user_secret_kms_key_id
  iam_database_authentication_enabled = each.value.iam_database_authentication_enabled

  db_subnet_group_name = (
    each.value.db_subnet_group_key_name != null
    ? aws_db_subnet_group.this[each.value.db_subnet_group_key_name].name
    : null
  )
  vpc_security_group_ids = each.value.vpc_security_group_ids
  publicly_accessible    = false

  multi_az = each.value.multi_az

  backup_retention_period   = each.value.backup_retention_period
  skip_final_snapshot       = each.value.skip_final_snapshot
  final_snapshot_identifier = each.value.skip_final_snapshot ? null : "${each.value.identifier}-final-${random_id.final_snapshot[each.key].hex}"

  deletion_protection = each.value.deletion_protection

  apply_immediately               = each.value.apply_immediately
  auto_minor_version_upgrade      = each.value.auto_minor_version_upgrade
  allow_major_version_upgrade     = each.value.allow_major_version_upgrade
  copy_tags_to_snapshot           = each.value.copy_tags_to_snapshot
  enabled_cloudwatch_logs_exports = each.value.enabled_cloudwatch_logs_exports
  performance_insights_enabled    = each.value.performance_insights_enabled

  tags = var.tags

  depends_on = [aws_cloudwatch_log_group.rds]
}

resource "aws_db_subnet_group" "this" {
  for_each = local.rds_subnet_mappings

  name        = each.value.name
  description = each.value.description
  subnet_ids  = each.value.subnet_ids

  tags = merge(
    { Name = format("%s-%s-%s-subnet-group", var.project, var.env, each.key) },
    var.tags
  )
}

resource "aws_db_parameter_group" "this" {
  for_each = var.parameters

  name   = each.value.name
  family = each.value.family

  dynamic "parameter" {
    for_each = each.value.parameter
    content {
      name         = parameter.value.name
      value        = parameter.value.value
      apply_method = parameter.value.apply_method
    }
  }
}

# Suffix for the final snapshot name so a recreated instance never collides with an old snapshot.
resource "random_id" "final_snapshot" {
  for_each = var.rds

  byte_length = 4
  keepers     = { identifier = each.value.identifier }
}
