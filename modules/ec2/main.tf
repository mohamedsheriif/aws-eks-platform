resource "aws_instance" "this" {
  for_each = var.ec2_instances

  ami                         = each.value.ami_id
  instance_type               = each.value.instance_type
  subnet_id                   = each.value.subnet_id
  vpc_security_group_ids      = each.value.security_group_ids
  associate_public_ip_address = each.value.associate_public_ip
  user_data                   = each.value.user_data
  iam_instance_profile        = each.value.iam_instance_profile
  monitoring                  = each.value.enable_monitoring
  source_dest_check           = each.value.source_dest_check

  root_block_device {
    delete_on_termination = each.value.delete_on_termination
    encrypted             = true
    kms_key_id            = each.value.kms_key_id
  }

  metadata_options {
    http_tokens   = "required"
    http_endpoint = "enabled"
  }

  tags = merge({
    Name = format("%s-%s-%s-ec2", var.project, var.env, each.key)
  }, var.tags)

  lifecycle {
    create_before_destroy = true
  }
}
