output "cert_arns" {
  description = "Map of certificate keys to their validated certificate ARNs"
  value       = { for k, v in aws_acm_certificate_validation.this : k => v.certificate_arn }
}
