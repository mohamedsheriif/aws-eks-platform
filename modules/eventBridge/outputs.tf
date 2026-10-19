output "rule_arns" {
  description = "Map of rule keys to their ARNs"
  value       = { for k, v in aws_cloudwatch_event_rule.this : k => v.arn }
}
