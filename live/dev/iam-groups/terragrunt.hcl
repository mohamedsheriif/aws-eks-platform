include "root" {
  path = find_in_parent_folders("root.hcl")
}

locals {
  env = read_terragrunt_config(find_in_parent_folders("env.hcl")).locals
}

terraform {
  source = "${get_repo_root()}/modules/iam-groups"
}

dependency "iam_roles" {
  config_path = "../iam-roles"

  mock_outputs = {
    role_arns = {
      eks-admin     = "arn:aws:iam::111111111111:role/mock-eks-admin"
      eks-developer = "arn:aws:iam::111111111111:role/mock-eks-developer"
    }
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan"]
}

inputs = {
  # EKS access entries only accept roles, so each group may assume exactly one role
  # and the role is what gets cluster access.
  groups = {
    admins = {
      name = "${local.env.project}-${local.env.env}-admins"
      inline_policies = {
        assume-eks-admin = jsonencode({
          Version = "2012-10-17"
          Statement = [{
            Effect   = "Allow"
            Action   = "sts:AssumeRole"
            Resource = dependency.iam_roles.outputs.role_arns["eks-admin"]
          }]
        })
      }
    }

    developers = {
      name = "${local.env.project}-${local.env.env}-developers"
      inline_policies = {
        assume-eks-developer = jsonencode({
          Version = "2012-10-17"
          Statement = [{
            Effect   = "Allow"
            Action   = "sts:AssumeRole"
            Resource = dependency.iam_roles.outputs.role_arns["eks-developer"]
          }]
        })
      }
    }
  }
}
