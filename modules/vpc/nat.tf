# Zonal: lives in one public subnet with an EIP from var.eip.
# Regional: spans every AZ of the VPC and gets its public IPs from AWS; no subnet or EIP.
resource "aws_nat_gateway" "this" {
  for_each = var.nat

  availability_mode = each.value.availability_mode
  vpc_id            = each.value.availability_mode == "regional" ? aws_vpc.this[each.value.vpc_key].id : null
  subnet_id         = each.value.availability_mode == "zonal" ? aws_subnet.this[each.value.subnet_key].id : null
  allocation_id     = each.value.availability_mode == "zonal" ? aws_eip.this[each.value.eip_key].id : null

  tags = merge({
    Name = format("%s-%s-%s-nat", var.project, var.env, each.key) },
    var.tags
  )

  depends_on = [aws_internet_gateway.this]
}
