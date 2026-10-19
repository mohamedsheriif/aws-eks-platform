resource "aws_vpc_endpoint" "this" {
  for_each = var.vpc_endpoints

  vpc_id            = aws_vpc.this[each.value.vpc_key].id
  service_name      = each.value.service_name
  vpc_endpoint_type = "Gateway"
  route_table_ids   = [for rt_key in each.value.route_table_keys : aws_route_table.this[rt_key].id]
  policy            = each.value.policy_json

  tags = merge(
    { Name = format("%s-%s-%s-vpce", var.project, var.env, each.key) },
    var.tags
  )
}
