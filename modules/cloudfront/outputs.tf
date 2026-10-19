output "cloudfront_distribution_ids" {
  description = "Map of distribution keys to their IDs"
  value       = { for k, v in aws_cloudfront_distribution.this : k => v.id }
}

output "cloudfront_distribution_arns" {
  description = "Map of distribution keys to their ARNs"
  value       = { for k, v in aws_cloudfront_distribution.this : k => v.arn }
}

output "cloudfront_distribution_domains" {
  description = "Map of distribution keys to their CloudFront domain names"
  value       = { for k, v in aws_cloudfront_distribution.this : k => v.domain_name }
}

output "origin_access_control_ids" {
  description = "Map of origin access control keys to their IDs"
  value       = { for k, v in aws_cloudfront_origin_access_control.this : k => v.id }
}
