output "db_instance_identifiers" {
  description = "RDS instance identifiers"
  value       = { for k, v in aws_db_instance.main : k => v.identifier }
}

output "db_instance_arns" {
  description = "RDS instance ARNs"
  value       = { for k, v in aws_db_instance.main : k => v.arn }
}

output "db_endpoints" {
  description = "RDS endpoints (host:port)"
  value       = { for k, v in aws_db_instance.main : k => v.endpoint }
}

output "db_instance_resource_ids" {
  description = "RDS instance resource IDs, for rds-db:connect IAM policies"
  value       = { for k, v in aws_db_instance.main : k => v.resource_id }
}

output "master_user_secret_arns" {
  description = "Secrets Manager secrets holding the RDS-managed master passwords"
  value       = { for k, v in aws_db_instance.main : k => try(v.master_user_secret[0].secret_arn, null) }
}
