resource "aws_acm_certificate" "this" {
  for_each = var.acm

  domain_name               = each.value.domain_name
  validation_method         = "DNS"
  subject_alternative_names = each.value.subject_alternative_names

  tags = merge({
    Name = format("%s-%s-%s-cert", var.project, var.env, each.key)
  }, var.tags)

  lifecycle {
    create_before_destroy = true
  }
}

# Keyed by domain name, which is known at plan time. A wildcard and its apex
# share one validation record, which allow_overwrite makes harmless.
resource "aws_route53_record" "validation" {
  for_each = merge([
    for k, v in var.acm : {
      for dvo in aws_acm_certificate.this[k].domain_validation_options :
      "${k}/${dvo.domain_name}" => {
        zone_id = v.route53_zone_id
        name    = dvo.resource_record_name
        type    = dvo.resource_record_type
        record  = dvo.resource_record_value
      }
    }
  ]...)

  zone_id         = each.value.zone_id
  name            = each.value.name
  type            = each.value.type
  records         = [each.value.record]
  ttl             = 60
  allow_overwrite = true
}

resource "aws_acm_certificate_validation" "this" {
  for_each = var.acm

  certificate_arn = aws_acm_certificate.this[each.key].arn

  validation_record_fqdns = [
    for dvo in aws_acm_certificate.this[each.key].domain_validation_options :
    dvo.resource_record_name
  ]

  depends_on = [aws_route53_record.validation]
}
