resource "aws_internet_gateway" "this" {
  for_each = local.vpc_igw

  vpc_id = aws_vpc.this[each.key].id

  tags = merge({
    Name = format("%s-%s-igw", var.project, var.env) },
    var.tags
  )
}
