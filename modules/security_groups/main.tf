resource "aws_security_group" "this" {
  for_each = var.security_groups

  name        = each.value.name
  vpc_id      = var.vpc_id
  description = coalesce(each.value.description, "Managed by Terraform")

  tags = merge(
    { Name = format("%s-%s-%s-sg", var.project, var.env, each.key) },
    var.tags,
    coalesce(each.value.tags, {})
  )
}

resource "aws_vpc_security_group_ingress_rule" "this" {
  for_each = local.ingress_rules

  security_group_id = aws_security_group.this[each.value.sg_key].id
  description       = each.value.description
  ip_protocol       = each.value.protocol
  from_port         = each.value.protocol == "-1" ? null : each.value.from_port
  to_port           = each.value.protocol == "-1" ? null : each.value.to_port

  cidr_ipv4 = each.value.kind == "cidr" ? each.value.value : null
  referenced_security_group_id = (
    each.value.kind == "sg" ? each.value.value
    : each.value.kind == "sg_key" ? aws_security_group.this[each.value.value].id
    : each.value.kind == "self" ? aws_security_group.this[each.value.sg_key].id
    : null
  )

  tags = var.tags
}

resource "aws_vpc_security_group_egress_rule" "this" {
  for_each = local.egress_rules

  security_group_id = aws_security_group.this[each.value.sg_key].id
  description       = each.value.description
  ip_protocol       = each.value.protocol
  from_port         = each.value.protocol == "-1" ? null : each.value.from_port
  to_port           = each.value.protocol == "-1" ? null : each.value.to_port

  cidr_ipv4 = each.value.kind == "cidr" ? each.value.value : null
  referenced_security_group_id = (
    each.value.kind == "sg" ? each.value.value
    : each.value.kind == "sg_key" ? aws_security_group.this[each.value.value].id
    : null
  )

  tags = var.tags
}
