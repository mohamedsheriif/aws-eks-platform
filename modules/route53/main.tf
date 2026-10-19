resource "aws_route53_zone" "this" {
  for_each = var.zones

  name          = each.value.name
  comment       = each.value.comment
  force_destroy = each.value.force_destroy

  tags = merge({
    Name = format("%s-%s-%s-zone", var.project, var.env, each.key)
  }, var.tags)
}
