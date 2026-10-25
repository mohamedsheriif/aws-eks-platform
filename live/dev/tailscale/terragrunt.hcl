include "root" {
  path = find_in_parent_folders("root.hcl")
}

locals {
  env = read_terragrunt_config(find_in_parent_folders("env.hcl")).locals
}

terraform {
  source = "${get_repo_root()}/modules/ec2"
}

dependency "vpc" {
  config_path = "../vpc"

  mock_outputs = {
    subnet_ids      = { public-us-east-1a = "subnet-mock-public-a" }
    vpc_cidr_blocks = { main = "10.10.0.0/16" }
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

dependency "iam_roles" {
  config_path = "../iam-roles"

  mock_outputs = {
    instance_profile_names = { tailscale = "mock-tailscale" }
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan"]
}

dependency "kms" {
  config_path = "../kms"

  mock_outputs = {
    kms_key_arns = { ebs = "arn:aws:kms:us-east-1:111111111111:key/mock-ebs" }
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan"]
}

dependency "secrets_manager" {
  config_path = "../secrets-manager"

  mock_outputs = {
    secret_arns = { tailscale-auth-key = "arn:aws:secretsmanager:us-east-1:111111111111:secret:mock-tailscale" }
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan"]
}

inputs = {
  project = local.env.project
  env     = local.env.env
  tags    = local.env.tags

  # Subnet router: makes the whole VPC (private EKS API, RDS, Valkey, internal ALB)
  # reachable from the tailnet. No inbound rules; Tailscale only connects outbound.
  ec2_instances = {
    tailscale = {
      # TG_MOCK can't call SSM, so local plans use a placeholder AMI.
      ami_id               = get_env("TG_MOCK", "false") == "true" ? "ami-mock" : null
      ami_ssm_parameter    = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-arm64"
      instance_type        = "t4g.nano"
      subnet_id            = dependency.vpc.outputs.subnet_ids["public-us-east-1a"]
      associate_public_ip  = true
      security_group_ids   = [dependency.security_groups.outputs.security_group_ids["tailscale"]]
      iam_instance_profile = dependency.iam_roles.outputs.instance_profile_names["tailscale"]
      kms_key_id           = dependency.kms.outputs.kms_key_arns["ebs"]

      user_data = <<-EOF
        #!/bin/bash
        set -euo pipefail

        curl -fsSL https://pkgs.tailscale.com/stable/amazon-linux/2023/tailscale.repo -o /etc/yum.repos.d/tailscale.repo
        dnf install -y tailscale

        cat > /etc/sysctl.d/99-tailscale.conf <<SYSCTL
        net.ipv4.ip_forward = 1
        net.ipv6.conf.all.forwarding = 1
        SYSCTL
        sysctl -p /etc/sysctl.d/99-tailscale.conf

        systemctl enable --now tailscaled

        AUTH_KEY=$(aws secretsmanager get-secret-value \
          --region ${local.env.region} \
          --secret-id ${dependency.secrets_manager.outputs.secret_arns["tailscale-auth-key"]} \
          --query SecretString --output text)

        tailscale up \
          --authkey="$AUTH_KEY" \
          --hostname=${local.env.project}-${local.env.env}-router \
          --advertise-routes=${dependency.vpc.outputs.vpc_cidr_blocks["main"]} \
          --accept-dns=false
      EOF
    }
  }
}
