resource "aws_route53_zone" "this" {
  for_each = var.zones

  name          = each.value.name
  comment       = each.value.comment
  force_destroy = each.value.force_destroy

  tags = merge({
    Name = format("%s-%s-%s-zone", var.project, var.env, each.key)
  }, var.tags)
}

resource "aws_route53_record" "this" {
  for_each = var.records

  zone_id = aws_route53_zone.this[each.value.zone_key].zone_id
  name    = each.value.name
  type    = each.value.type
  ttl     = each.value.ttl
  records = each.value.records
}
