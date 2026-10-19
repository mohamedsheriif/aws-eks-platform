output "user_pool_ids" {
  description = "User pool IDs keyed by user pool map key"
  value       = { for k, p in aws_cognito_user_pool.this : k => p.id }
}

output "user_pool_arns" {
  description = "User pool ARNs keyed by user pool map key"
  value       = { for k, p in aws_cognito_user_pool.this : k => p.arn }
}

output "user_pool_endpoints" {
  description = "User pool issuer endpoints (for JWT validation) keyed by user pool map key"
  value       = { for k, p in aws_cognito_user_pool.this : k => p.endpoint }
}

output "user_pool_client_ids" {
  description = "App client IDs keyed by client map key"
  value       = { for k, c in aws_cognito_user_pool_client.this : k => c.id }
}

output "user_pool_domains" {
  description = "Custom domain CloudFront targets keyed by user pool map key, for Route 53 alias records"
  value = {
    for k, d in aws_cognito_user_pool_domain.this : k => {
      domain                  = d.domain
      cloudfront_distribution = d.cloudfront_distribution
      cloudfront_zone_id      = d.cloudfront_distribution_zone_id
    }
  }
}
