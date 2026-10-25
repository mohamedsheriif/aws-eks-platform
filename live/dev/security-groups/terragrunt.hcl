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
    vpc_ids         = { main = "vpc-mock" }
    vpc_cidr_blocks = { main = "10.10.0.0/16" }
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan"]
}

inputs = {
  project = local.env.project
  env     = local.env.env
  tags    = local.env.tags
  vpc_id  = dependency.vpc.outputs.vpc_ids["main"]

  security_groups = {
    # Tailscale subnet router. No inbound rules: Tailscale only makes outbound connections.
    tailscale = {
      name        = "${local.env.project}-${local.env.env}-tailscale"
      description = "Tailscale subnet router"
      egress_rules = [
        {
          description = "Tailscale coordination, DERP relays and package repos"
          protocol    = "tcp"
          from_port   = 443
          to_port     = 443
          cidr_blocks = ["0.0.0.0/0"]
        },
        {
          description = "WireGuard direct connections"
          protocol    = "udp"
          from_port   = 41641
          to_port     = 41641
          cidr_blocks = ["0.0.0.0/0"]
        },
        {
          description = "STUN for NAT traversal"
          protocol    = "udp"
          from_port   = 3478
          to_port     = 3478
          cidr_blocks = ["0.0.0.0/0"]
        },
        {
          description = "Forward tailnet traffic into the VPC"
          protocol    = "-1"
          from_port   = 0
          to_port     = 0
          cidr_blocks = [dependency.vpc.outputs.vpc_cidr_blocks["main"]]
        },
      ]
    }

    # Attached to the EKS control plane ENIs. The API endpoint is private, so this is the only way in.
    eks-api = {
      name        = "${local.env.project}-${local.env.env}-eks-api"
      description = "EKS API access from the Tailscale router"
      ingress_rules = [
        {
          description                = "Kubernetes API from Tailscale"
          protocol                   = "tcp"
          from_port                  = 443
          to_port                    = 443
          source_security_group_keys = ["tailscale"]
        },
      ]
    }
  }
}
