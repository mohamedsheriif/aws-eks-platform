include "root" {
  path = find_in_parent_folders("root.hcl")
}

locals {
  env = read_terragrunt_config(find_in_parent_folders("env.hcl")).locals
}

terraform {
  source = "${get_repo_root()}/modules/eventBridge"
}

dependency "sqs" {
  config_path = "../sqs"

  mock_outputs = {
    queue_arns = { karpenter = "arn:aws:sqs:us-east-1:222222222222:shopflow-prod-karpenter" }
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan"]
}

# Events Karpenter acts on, forwarded to its interruption queue. These are the rules from
# Karpenter's reference setup.
inputs = {
  project = local.env.project
  env     = local.env.env
  tags    = local.env.tags

  rules = {
    karpenter-health = {
      name          = "${local.env.project}-${local.env.env}-karpenter-health"
      description   = "AWS Health scheduled changes for EC2"
      event_pattern = jsonencode({ source = ["aws.health"], detail-type = ["AWS Health Event"] })
      target_arn    = dependency.sqs.outputs.queue_arns["karpenter"]
    }
    karpenter-spot-interruption = {
      name          = "${local.env.project}-${local.env.env}-karpenter-spot-interruption"
      description   = "Two-minute Spot interruption warnings"
      event_pattern = jsonencode({ source = ["aws.ec2"], detail-type = ["EC2 Spot Instance Interruption Warning"] })
      target_arn    = dependency.sqs.outputs.queue_arns["karpenter"]
    }
    karpenter-rebalance = {
      name          = "${local.env.project}-${local.env.env}-karpenter-rebalance"
      description   = "Spot rebalance recommendations"
      event_pattern = jsonencode({ source = ["aws.ec2"], detail-type = ["EC2 Instance Rebalance Recommendation"] })
      target_arn    = dependency.sqs.outputs.queue_arns["karpenter"]
    }
    karpenter-instance-state = {
      name          = "${local.env.project}-${local.env.env}-karpenter-instance-state"
      description   = "EC2 instance state changes"
      event_pattern = jsonencode({ source = ["aws.ec2"], detail-type = ["EC2 Instance State-change Notification"] })
      target_arn    = dependency.sqs.outputs.queue_arns["karpenter"]
    }
    karpenter-capacity-reservation = {
      name          = "${local.env.project}-${local.env.env}-karpenter-capacity-reservation"
      description   = "Capacity reservation interruption warnings"
      event_pattern = jsonencode({ source = ["aws.ec2"], detail-type = ["EC2 Capacity Reservation Instance Interruption Warning"] })
      target_arn    = dependency.sqs.outputs.queue_arns["karpenter"]
    }
  }
}
