include "root" {
  path = find_in_parent_folders("root.hcl")
}

locals {
  env = read_terragrunt_config(find_in_parent_folders("env.hcl")).locals
}

terraform {
  source = "${get_repo_root()}/modules/secrets_manager"
}

dependency "kms" {
  config_path = "../kms"

  mock_outputs = {
    kms_key_arns = { secrets = "arn:aws:kms:us-east-1:111111111111:key/mock-secrets" }
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan"]
}

# Secrets are created empty; their values are set outside Terraform so they never land in state.
# Everything under <project>/<env>/ is readable by External Secrets Operator.
inputs = {
  project = local.env.project
  env     = local.env.env
  tags    = local.env.tags

  secrets = {
    # Read by the Tailscale instance at boot.
    tailscale-auth-key = {
      name                    = "${local.env.project}/${local.env.env}/tailscale/auth-key"
      description             = "Tailscale auth key for the subnet router"
      kms_key_id              = dependency.kms.outputs.kms_key_arns["secrets"]
      recovery_window_in_days = 0
    }

    # Synced by ESO into monitoring/grafana-admin. JSON: {"username": "...", "password": "..."}.
    grafana-admin = {
      name                    = "${local.env.project}/${local.env.env}/grafana/admin"
      description             = "Grafana admin credentials"
      kms_key_id              = dependency.kms.outputs.kms_key_arns["secrets"]
      recovery_window_in_days = 0
    }

    # Synced by ESO into an Argo CD repository secret for the private GitOps repo.
    # JSON: {"username": "<github user>", "password": "<fine-grained PAT, contents read-only>"}.
    argocd-gitops-repo = {
      name                    = "${local.env.project}/${local.env.env}/argocd/gitops-repo"
      description             = "Argo CD read-only credentials for the GitOps repository"
      kms_key_id              = dependency.kms.outputs.kms_key_arns["secrets"]
      recovery_window_in_days = 0
    }

    # One JSON secret per microservice. ESO syncs each into a Kubernetes Secret in the
    # apps namespace and the service loads it as environment variables.
    catalog-env = {
      name                    = "${local.env.project}/${local.env.env}/catalog/env"
      description             = "Sensitive environment variables for the catalog service"
      kms_key_id              = dependency.kms.outputs.kms_key_arns["secrets"]
      recovery_window_in_days = 0
    }
    users-env = {
      name                    = "${local.env.project}/${local.env.env}/users/env"
      description             = "Sensitive environment variables for the users service"
      kms_key_id              = dependency.kms.outputs.kms_key_arns["secrets"]
      recovery_window_in_days = 0
    }
    orders-env = {
      name                    = "${local.env.project}/${local.env.env}/orders/env"
      description             = "Sensitive environment variables for the orders service"
      kms_key_id              = dependency.kms.outputs.kms_key_arns["secrets"]
      recovery_window_in_days = 0
    }
    payments-env = {
      name                    = "${local.env.project}/${local.env.env}/payments/env"
      description             = "Sensitive environment variables for the payments service (payment provider API keys)"
      kms_key_id              = dependency.kms.outputs.kms_key_arns["secrets"]
      recovery_window_in_days = 0
    }
    notifications-env = {
      name                    = "${local.env.project}/${local.env.env}/notifications/env"
      description             = "Sensitive environment variables for the notifications service"
      kms_key_id              = dependency.kms.outputs.kms_key_arns["secrets"]
      recovery_window_in_days = 0
    }
  }
}
