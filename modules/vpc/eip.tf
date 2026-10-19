resource "aws_eip" "this" {
  for_each = var.eip

  domain = "vpc"

  tags = merge({
    Name = format("%s-%s-%s-eip", var.project, var.env, each.key) },
    var.tags
  )
}
