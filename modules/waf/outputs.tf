output "web_acl_arns" {
  description = "Map of web ACL keys to their ARNs"
  value       = { for k, acl in aws_wafv2_web_acl.this : k => acl.arn }
}
