include "root" {
  path = find_in_parent_folders("root-helm.hcl")
}

locals {
  env = read_terragrunt_config(find_in_parent_folders("env.hcl")).locals
}

terraform {
  source = "${get_repo_root()}/modules/helm"
}

dependency "eks" {
  config_path = "../eks"

  mock_outputs = {
    cluster_names = { main = "shopflow-dev" }
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan"]
}

dependency "vpc" {
  config_path = "../vpc"

  mock_outputs = {
    vpc_ids = { main = "vpc-mock" }
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan"]
}

dependency "acm" {
  config_path = "../acm"

  mock_outputs = {
    cert_arns = { main = "arn:aws:acm:us-east-1:111111111111:certificate/mock" }
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

# Controllers, CRDs and cluster-wide objects that helm-platform builds on:
# its Ingresses need the ALB controller webhook and IngressClasses, its PVCs need
# the gp3 StorageClass, and its ServiceMonitors need the Prometheus Operator CRDs.
inputs = {
  releases = {
    aws-load-balancer-controller = {
      name             = "aws-load-balancer-controller"
      repository       = "https://aws.github.io/eks-charts"
      chart            = "aws-load-balancer-controller"
      version          = "3.6.1"
      namespace        = "kube-system"
      create_namespace = false
      values = [templatefile("${get_terragrunt_dir()}/values/aws-load-balancer-controller.yaml", {
        cluster_name = dependency.eks.outputs.cluster_names["main"]
        region       = local.env.region
        vpc_id       = dependency.vpc.outputs.vpc_ids["main"]
        tags         = jsonencode(local.env.tags)
      })]
    }

    external-secrets = {
      name       = "external-secrets"
      repository = "https://charts.external-secrets.io"
      chart      = "external-secrets"
      version    = "2.13.0"
      namespace  = "external-secrets"
      values     = [file("${get_terragrunt_dir()}/values/external-secrets.yaml")]
    }

    # Installed on its own so the CRDs exist before any chart ships a ServiceMonitor;
    # kube-prometheus-stack runs with crds.enabled = false.
    prometheus-operator-crds = {
      name       = "prometheus-operator-crds"
      repository = "oci://ghcr.io/prometheus-community/charts"
      chart      = "prometheus-operator-crds"
      version    = "32.0.1"
      namespace  = "monitoring"
    }
  }

  manifests = {
    storageclass-gp3 = templatefile("${get_terragrunt_dir()}/manifests/storageclass-gp3.yaml", {
      kms_key_arn = dependency.kms.outputs.kms_key_arns["ebs"]
    })

    ingressclassparams-alb-internal = templatefile("${get_terragrunt_dir()}/manifests/ingressclassparams-alb-internal.yaml", {
      group           = "${local.env.project}-${local.env.env}-internal"
      certificate_arn = dependency.acm.outputs.cert_arns["main"]
    })
    ingressclass-alb-internal = file("${get_terragrunt_dir()}/manifests/ingressclass-alb-internal.yaml")

    ingressclassparams-alb-public = templatefile("${get_terragrunt_dir()}/manifests/ingressclassparams-alb-public.yaml", {
      group           = "${local.env.project}-${local.env.env}-public"
      certificate_arn = dependency.acm.outputs.cert_arns["main"]
    })
    ingressclass-alb-public = file("${get_terragrunt_dir()}/manifests/ingressclass-alb-public.yaml")

    # The monitoring namespace already exists: the prometheus-operator-crds release creates it.
    secretstore-monitoring = templatefile("${get_terragrunt_dir()}/manifests/secretstore-monitoring.yaml", {
      region = local.env.region
    })
    externalsecret-grafana-admin = templatefile("${get_terragrunt_dir()}/manifests/externalsecret-grafana-admin.yaml", {
      secret_name = "${local.env.project}/${local.env.env}/grafana/admin"
    })
  }
}
