include "root" {
  path = find_in_parent_folders("root.hcl")
}

locals {
  env = read_terragrunt_config(find_in_parent_folders("env.hcl")).locals
}

terraform {
  source = "${get_repo_root()}/modules/security_groups"
}

dependency "vpc" {
  config_path = "../vpc"

  mock_outputs = {
    vpc_ids = { main = "vpc-mock" }
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan"]
}

dependency "security_groups" {
  config_path = "../security-groups"

  mock_outputs = {
    security_group_ids = { tailscale = "sg-mock-tailscale" }
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan"]
}

dependency "eks" {
  config_path = "../eks"

  mock_outputs = {
    cluster_security_group_ids = { main = "sg-mock-eks-cluster" }
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan"]
}

# Separate from the security-groups unit because the EKS cluster security group
# only exists after the cluster is created.
inputs = {
  project = local.env.project
  env     = local.env.env
  tags    = local.env.tags
  vpc_id  = dependency.vpc.outputs.vpc_ids["main"]

  security_groups = {
    rds = {
      name        = "${local.env.project}-${local.env.env}-rds"
      description = "PostgreSQL from EKS nodes and pods, and Tailscale"
      ingress_rules = [
        {
          description     = "PostgreSQL from EKS"
          protocol        = "tcp"
          from_port       = 5432
          to_port         = 5432
          security_groups = [dependency.eks.outputs.cluster_security_group_ids["main"]]
        },
        {
          description     = "PostgreSQL from Tailscale"
          protocol        = "tcp"
          from_port       = 5432
          to_port         = 5432
          security_groups = [dependency.security_groups.outputs.security_group_ids["tailscale"]]
        },
      ]
    }

    redis = {
      name        = "${local.env.project}-${local.env.env}-redis"
      description = "Valkey from EKS nodes and pods, and Tailscale"
      ingress_rules = [
        {
          description     = "Valkey from EKS"
          protocol        = "tcp"
          from_port       = 6379
          to_port         = 6379
          security_groups = [dependency.eks.outputs.cluster_security_group_ids["main"]]
        },
        {
          description     = "Valkey from Tailscale"
          protocol        = "tcp"
          from_port       = 6379
          to_port         = 6379
          security_groups = [dependency.security_groups.outputs.security_group_ids["tailscale"]]
        },
      ]
    }
  }
}
