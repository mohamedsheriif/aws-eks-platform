output "email_identity_arns" {
  description = "Map of identity keys to their ARNs"
  value       = { for k, v in aws_sesv2_email_identity.this : k => v.arn }
}

output "configuration_set_arns" {
  description = "Map of configuration set keys to their ARNs"
  value       = { for k, v in aws_sesv2_configuration_set.this : k => v.arn }
}
