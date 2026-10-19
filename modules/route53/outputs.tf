output "zone_ids" {
  description = "Hosted zone IDs keyed by zone map key"
  value       = { for k, z in aws_route53_zone.this : k => z.zone_id }
}

output "name_servers" {
  description = "Name servers keyed by zone map key, to delegate from the parent domain"
  value       = { for k, z in aws_route53_zone.this : k => z.name_servers }
}
