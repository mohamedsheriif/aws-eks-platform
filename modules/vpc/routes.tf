resource "aws_route_table" "this" {
  for_each = var.route_tables

  vpc_id = aws_vpc.this[each.value.vpc_key].id

  dynamic "route" {
    for_each = each.value.routes
    content {
      cidr_block     = lookup(route.value, "cidr_block", null)
      gateway_id     = each.value.use_igw ? aws_internet_gateway.this[each.value.vpc_key].id : null
      nat_gateway_id = each.value.use_nat ? aws_nat_gateway.this[each.value.nat_key].id : null
    }
  }

  tags = merge(
    { Name = format("%s-%s-%s", var.project, var.env, each.key) },
    var.tags
  )
}

resource "aws_route_table_association" "this" {
  for_each = local.subnet_routing_map

  route_table_id = aws_route_table.this[each.value.route_table_key].id
  subnet_id      = aws_subnet.this[each.value.subnet_key].id
}
