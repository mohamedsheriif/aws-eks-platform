resource "aws_subnet" "this" {
  for_each = var.subnets

  vpc_id                  = aws_vpc.this[each.value.vpc_key].id
  availability_zone       = each.value.availability_zone
  cidr_block              = each.value.cidr_block
  map_public_ip_on_launch = each.value.map_public_ip_on_launch

  tags = merge(
    {
      Name              = format("%s-%s-%s", var.project, var.env, each.key)
      availability_zone = each.value.availability_zone
    },
    var.tags,
    each.value.tags
  )
}

resource "aws_network_acl" "this" {
  for_each = local.subnets_with_nacl

  vpc_id     = aws_vpc.this[each.value.vpc_key].id
  subnet_ids = [aws_subnet.this[each.key].id]

  dynamic "ingress" {
    for_each = [for r in each.value.rules : r if !lookup(r, "egress", false)]
    content {
      protocol   = ingress.value.protocol
      rule_no    = ingress.value.rule_no
      action     = ingress.value.action
      cidr_block = ingress.value.cidr_block
      from_port  = ingress.value.from_port
      to_port    = ingress.value.to_port
    }
  }

  dynamic "egress" {
    for_each = [for r in each.value.rules : r if lookup(r, "egress", false)]
    content {
      protocol   = egress.value.protocol
      rule_no    = egress.value.rule_no
      action     = egress.value.action
      cidr_block = egress.value.cidr_block
      from_port  = egress.value.from_port
      to_port    = egress.value.to_port
    }
  }

  tags = merge(
    { Name = format("%s-%s-%s-nacl", var.project, var.env, each.key) },
    var.tags
  )
}
