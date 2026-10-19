locals {
  alias_records = merge([
    for k, d in var.cloudfront_distributions : merge([
      for alias in d.aliases : {
        for type in(d.is_ipv6_enabled ? ["A", "AAAA"] : ["A"]) :
        "${k}/${alias}/${type}" => { dist_key = k, zone_id = d.route53_zone_id, name = alias, type = type }
      }
    ]...) if d.route53_zone_id != null
  ]...)
}

resource "aws_route53_record" "alias" {
  for_each = local.alias_records

  zone_id = each.value.zone_id
  name    = each.value.name
  type    = each.value.type

  alias {
    name                   = aws_cloudfront_distribution.this[each.value.dist_key].domain_name
    zone_id                = aws_cloudfront_distribution.this[each.value.dist_key].hosted_zone_id
    evaluate_target_health = false
  }
}
