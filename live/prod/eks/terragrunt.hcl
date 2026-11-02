include "root" {
  path = find_in_parent_folders("root.hcl")
}

locals {
  env = read_terragrunt_config(find_in_parent_folders("env.hcl")).locals
}

terraform {
  source = "${get_repo_root()}/modules/eks"
}

dependency "vpc" {
  config_path = "../vpc"

  mock_outputs = {
    subnet_ids = {
      app-us-east-1a = "subnet-mock-app-a"
      app-us-east-1b = "subnet-mock-app-b"
      app-us-east-1c = "subnet-mock-app-c"
    }
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan"]
}

dependency "security_groups" {
  config_path = "../security-groups"

  mock_outputs = {
    security_group_ids = { eks-api = "sg-mock-eks-api" }
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan"]
}

dependency "kms" {
  config_path = "../kms"

  mock_outputs = {
    kms_key_arns = {
      eks  = "arn:aws:kms:us-east-1:222222222222:key/mock-eks"
      ebs  = "arn:aws:kms:us-east-1:222222222222:key/mock-ebs"
      logs = "arn:aws:kms:us-east-1:222222222222:key/mock-logs"
    }
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan"]
}

dependency "iam_roles" {
  config_path = "../iam-roles"

  mock_outputs = {
    role_arns = {
      eks-cluster                  = "arn:aws:iam::222222222222:role/mock-eks-cluster"
      eks-node                     = "arn:aws:iam::222222222222:role/mock-eks-node"
      eks-admin                    = "arn:aws:iam::222222222222:role/mock-eks-admin"
      eks-developer                = "arn:aws:iam::222222222222:role/mock-eks-developer"
      vpc-cni                      = "arn:aws:iam::222222222222:role/mock-vpc-cni"
      ebs-csi                      = "arn:aws:iam::222222222222:role/mock-ebs-csi"
      aws-load-balancer-controller = "arn:aws:iam::222222222222:role/mock-aws-load-balancer-controller"
      external-dns                 = "arn:aws:iam::222222222222:role/mock-external-dns"
      external-secrets             = "arn:aws:iam::222222222222:role/mock-external-secrets"
      loki                         = "arn:aws:iam::222222222222:role/mock-loki"
      karpenter-controller         = "arn:aws:iam::222222222222:role/mock-karpenter-controller"
      karpenter-node               = "arn:aws:iam::222222222222:role/mock-karpenter-node"
    }
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan"]
}

dependency "iam_roles_apps" {
  config_path = "../iam-roles-apps"

  mock_outputs = {
    role_arns = {
      catalog       = "arn:aws:iam::222222222222:role/mock-catalog"
      users         = "arn:aws:iam::222222222222:role/mock-users"
      orders        = "arn:aws:iam::222222222222:role/mock-orders"
      payments      = "arn:aws:iam::222222222222:role/mock-payments"
      notifications = "arn:aws:iam::222222222222:role/mock-notifications"
    }
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan"]
}

inputs = {
  project = local.env.project
  env     = local.env.env
  tags    = local.env.tags

  secrets_encryption_kms_key_arn = dependency.kms.outputs.kms_key_arns["eks"]

  # Private API endpoint only, reachable through Tailscale. All control plane log types go to
  # CloudWatch for 90 days. The cluster security group is tagged for Karpenter discovery.
  eks_clusters = {
    main = {
      name                      = "${local.env.project}-${local.env.env}"
      version                   = "1.34"
      role_arn                  = dependency.iam_roles.outputs.role_arns["eks-cluster"]
      subnet_ids                = [dependency.vpc.outputs.subnet_ids["app-us-east-1a"], dependency.vpc.outputs.subnet_ids["app-us-east-1b"], dependency.vpc.outputs.subnet_ids["app-us-east-1c"]]
      security_group_ids        = [dependency.security_groups.outputs.security_group_ids["eks-api"]]
      enabled_cluster_log_types = ["api", "audit", "authenticator", "controllerManager", "scheduler"]
      log_retention_days        = 90
      logs_kms_key_arn          = dependency.kms.outputs.kms_key_arns["logs"]
      karpenter_discovery       = true
    }
  }

  node_groups = {
    # Platform components (ALB controller, ArgoCD, monitoring).
    system = {
      cluster_key     = "main"
      name            = "system"
      node_role_arn   = dependency.iam_roles.outputs.role_arns["eks-node"]
      subnet_ids      = [dependency.vpc.outputs.subnet_ids["app-us-east-1a"], dependency.vpc.outputs.subnet_ids["app-us-east-1b"], dependency.vpc.outputs.subnet_ids["app-us-east-1c"]]
      instance_types  = ["t4g.large"]
      ami_type        = "AL2023_ARM_64_STANDARD"
      min_size        = 2
      max_size        = 3
      desired_size    = 2
      disk_size       = 50
      ebs_kms_key_arn = dependency.kms.outputs.kms_key_arns["ebs"]
      max_pods        = 110
      labels          = { role = "system" }
    }

    # On-demand baseline for application pods. Extra capacity comes from Karpenter on Spot.
    apps = {
      cluster_key     = "main"
      name            = "apps"
      node_role_arn   = dependency.iam_roles.outputs.role_arns["eks-node"]
      subnet_ids      = [dependency.vpc.outputs.subnet_ids["app-us-east-1a"], dependency.vpc.outputs.subnet_ids["app-us-east-1b"], dependency.vpc.outputs.subnet_ids["app-us-east-1c"]]
      instance_types  = ["t4g.large"]
      ami_type        = "AL2023_ARM_64_STANDARD"
      min_size        = 2
      max_size        = 2
      desired_size    = 2
      disk_size       = 50
      ebs_kms_key_arn = dependency.kms.outputs.kms_key_arns["ebs"]
      max_pods        = 110
      labels          = { role = "apps" }
    }
  }

  addons = {
    # Installed before the node groups so nodes become Ready with the right CNI settings.
    vpc-cni = {
      cluster_key    = "main"
      addon_name     = "vpc-cni"
      before_compute = true
      configuration_values = jsonencode({
        env = {
          ENABLE_PREFIX_DELEGATION = "true"
          WARM_PREFIX_TARGET       = "1"
        }
      })
      pod_identity_association = [{
        role_arn        = dependency.iam_roles.outputs.role_arns["vpc-cni"]
        service_account = "aws-node"
      }]
    }
    kube-proxy = {
      cluster_key    = "main"
      addon_name     = "kube-proxy"
      before_compute = true
    }
    eks-pod-identity-agent = {
      cluster_key    = "main"
      addon_name     = "eks-pod-identity-agent"
      before_compute = true
    }

    # Installed after the node groups; these run on the system nodes.
    coredns = {
      cluster_key = "main"
      addon_name  = "coredns"
      configuration_values = jsonencode({
        nodeSelector = { role = "system" }
        tolerations  = [{ key = "CriticalAddonsOnly", operator = "Exists" }]
      })
    }
    aws-ebs-csi-driver = {
      cluster_key = "main"
      addon_name  = "aws-ebs-csi-driver"
      configuration_values = jsonencode({
        controller = {
          nodeSelector = { role = "system" }
          tolerations  = [{ key = "CriticalAddonsOnly", operator = "Exists" }]
        }
      })
      pod_identity_association = [{
        role_arn        = dependency.iam_roles.outputs.role_arns["ebs-csi"]
        service_account = "ebs-csi-controller-sa"
      }]
    }
    metrics-server = {
      cluster_key = "main"
      addon_name  = "metrics-server"
      configuration_values = jsonencode({
        nodeSelector = { role = "system" }
        tolerations  = [{ key = "CriticalAddonsOnly", operator = "Exists" }]
      })
    }
  }

  # Roles assumed by the admins and developers IAM groups, and the role of Karpenter's nodes.
  access_entries = {
    admin = {
      cluster_key   = "main"
      principal_arn = dependency.iam_roles.outputs.role_arns["eks-admin"]
    }
    developer = {
      cluster_key   = "main"
      principal_arn = dependency.iam_roles.outputs.role_arns["eks-developer"]
    }
    karpenter-node = {
      cluster_key   = "main"
      principal_arn = dependency.iam_roles.outputs.role_arns["karpenter-node"]
      type          = "EC2_LINUX"
    }
  }

  access_policy_associations = {
    admin = {
      cluster_key   = "main"
      principal_arn = dependency.iam_roles.outputs.role_arns["eks-admin"]
      policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
      access_scope  = { type = "cluster" }
    }
    # Read-only on all namespaces; Secrets are not readable.
    developer = {
      cluster_key   = "main"
      principal_arn = dependency.iam_roles.outputs.role_arns["eks-developer"]
      policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSViewPolicy"
      access_scope  = { type = "cluster" }
    }
  }

  # vpc-cni and ebs-csi are bound through their add-ons above.
  pod_identity_associations = {
    aws-load-balancer-controller = {
      cluster_key     = "main"
      namespace       = "kube-system"
      service_account = "aws-load-balancer-controller"
      role_arn        = dependency.iam_roles.outputs.role_arns["aws-load-balancer-controller"]
    }
    external-dns = {
      cluster_key     = "main"
      namespace       = "kube-system"
      service_account = "external-dns"
      role_arn        = dependency.iam_roles.outputs.role_arns["external-dns"]
    }
    external-secrets = {
      cluster_key     = "main"
      namespace       = "external-secrets"
      service_account = "external-secrets"
      role_arn        = dependency.iam_roles.outputs.role_arns["external-secrets"]
    }
    karpenter = {
      cluster_key     = "main"
      namespace       = "kube-system"
      service_account = "karpenter"
      role_arn        = dependency.iam_roles.outputs.role_arns["karpenter-controller"]
    }
    loki = {
      cluster_key     = "main"
      namespace       = "logging"
      service_account = "loki"
      role_arn        = dependency.iam_roles.outputs.role_arns["loki"]
    }
    catalog = {
      cluster_key     = "main"
      namespace       = "apps"
      service_account = "catalog"
      role_arn        = dependency.iam_roles_apps.outputs.role_arns["catalog"]
    }
    users = {
      cluster_key     = "main"
      namespace       = "apps"
      service_account = "users"
      role_arn        = dependency.iam_roles_apps.outputs.role_arns["users"]
    }
    orders = {
      cluster_key     = "main"
      namespace       = "apps"
      service_account = "orders"
      role_arn        = dependency.iam_roles_apps.outputs.role_arns["orders"]
    }
    payments = {
      cluster_key     = "main"
      namespace       = "apps"
      service_account = "payments"
      role_arn        = dependency.iam_roles_apps.outputs.role_arns["payments"]
    }
    notifications = {
      cluster_key     = "main"
      namespace       = "apps"
      service_account = "notifications"
      role_arn        = dependency.iam_roles_apps.outputs.role_arns["notifications"]
    }
  }
}
