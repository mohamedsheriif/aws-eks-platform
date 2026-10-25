output "group_names" {
  description = "Map of group keys to their names"
  value       = { for k, v in aws_iam_group.this : k => v.name }
}

output "group_arns" {
  description = "Map of group keys to their ARNs"
  value       = { for k, v in aws_iam_group.this : k => v.arn }
}
