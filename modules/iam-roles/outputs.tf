output "role_arns" {
  description = "Map of role keys to their ARNs"
  value       = { for k, v in aws_iam_role.this : k => v.arn }
}

output "role_names" {
  description = "Map of role keys to their names"
  value       = { for k, v in aws_iam_role.this : k => v.name }
}

output "instance_profile_names" {
  description = "Map of role keys to their instance profile names (roles with create_instance_profile only)"
  value       = { for k, v in aws_iam_instance_profile.this : k => v.name }
}
