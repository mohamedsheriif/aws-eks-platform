output "primary_endpoints" {
  description = "Primary endpoint address of each cache, keyed by cache map key"
  value       = { for k, v in aws_elasticache_replication_group.this : k => v.primary_endpoint_address }
}

output "ports" {
  description = "Port of each cache, keyed by cache map key"
  value       = { for k, v in aws_elasticache_replication_group.this : k => v.port }
}

output "iam_user_arns" {
  description = "IAM-authenticated user ARNs, keyed by \"<cache key>/<user name>\", for elasticache:Connect policies"
  value       = { for k, v in aws_elasticache_user.iam : k => v.arn }
}

output "replication_group_arns" {
  description = "Replication group ARNs, keyed by cache map key"
  value       = { for k, v in aws_elasticache_replication_group.this : k => v.arn }
}
