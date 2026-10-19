output "role_arns" {
  description = "Map of role keys to their ARNs"
  value       = { for k, v in aws_iam_role.this : k => v.arn }
}

output "oidc_provider_arns" {
  description = "Map of OIDC provider keys to their ARNs"
  value       = { for k, v in aws_iam_openid_connect_provider.this : k => v.arn }
}
