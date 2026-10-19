locals {
  # AL2023 nodeadm config, merged by EKS with its own bootstrap config.
  node_user_data = {
    for k, v in var.node_groups : k => v.max_pods == null ? null : base64encode(<<-EOT
      MIME-Version: 1.0
      Content-Type: multipart/mixed; boundary="BOUNDARY"

      --BOUNDARY
      Content-Type: application/node.eks.aws

      ---
      apiVersion: node.eks.aws/v1alpha1
      kind: NodeConfig
      spec:
        kubelet:
          config:
            maxPods: ${v.max_pods}

      --BOUNDARY--
    EOT
    )
  }
}

resource "aws_launch_template" "node" {
  for_each = var.node_groups

  name_prefix            = format("%s-%s-", var.project, each.value.name)
  update_default_version = true
  user_data              = local.node_user_data[each.key]

  # Hop limit 1 keeps pods away from the node's credentials; pods use Pod Identity.
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  block_device_mappings {
    device_name = "/dev/xvda"

    ebs {
      volume_size           = each.value.disk_size
      volume_type           = "gp3"
      encrypted             = true
      kms_key_id            = each.value.ebs_kms_key_arn
      delete_on_termination = true
    }
  }

  tag_specifications {
    resource_type = "instance"
    tags          = merge({ Name = format("%s-node", each.value.name) }, var.tags)
  }

  tag_specifications {
    resource_type = "volume"
    tags          = merge({ Name = format("%s-node", each.value.name) }, var.tags)
  }

  tags = var.tags
}

resource "aws_eks_node_group" "this" {
  for_each = var.node_groups

  cluster_name    = aws_eks_cluster.this[each.value.cluster_key].name
  node_group_name = each.value.name
  node_role_arn   = each.value.node_role_arn
  subnet_ids      = each.value.subnet_ids

  scaling_config {
    desired_size = each.value.desired_size
    max_size     = each.value.max_size
    min_size     = each.value.min_size
  }

  instance_types = each.value.instance_types
  capacity_type  = each.value.capacity_type
  ami_type       = each.value.ami_type
  labels         = each.value.labels

  dynamic "taint" {
    for_each = each.value.taints
    content {
      key    = taint.value.key
      value  = taint.value.value
      effect = taint.value.effect
    }
  }

  launch_template {
    id      = aws_launch_template.node[each.key].id
    version = aws_launch_template.node[each.key].latest_version
  }

  tags = merge(
    { Name = format("%s-nodegroup", each.value.name) },
    var.tags
  )

  lifecycle {
    create_before_destroy = true
    ignore_changes        = [scaling_config[0].desired_size]
  }

  # Nodes only become Ready once the CNI add-on is installed.
  depends_on = [aws_eks_addon.before_compute]
}
