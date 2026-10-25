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

dependency "route53" {
  config_path = "../route53"

  mock_outputs = {
    zone_ids = { main = "Z0000000000MOCK" }
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan"]
}

dependency "s3" {
  config_path = "../s3"

  mock_outputs = {
    bucket_names = { loki = "shopflow-dev-loki-111111111111" }
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan"]
}

# Ordering only: IngressClasses, the gp3 StorageClass and the Prometheus Operator CRDs.
dependencies {
  paths = ["../helm-core"]
}

inputs = {
  releases = {
    external-dns = {
      name       = "external-dns"
      repository = "https://kubernetes-sigs.github.io/external-dns"
      chart      = "external-dns"
      version    = "1.23.0"
      namespace  = "kube-system"
      values = [templatefile("${get_terragrunt_dir()}/values/external-dns.yaml", {
        region   = local.env.region
        domain   = local.env.domain
        zone_id  = dependency.route53.outputs.zone_ids["main"]
        owner_id = dependency.eks.outputs.cluster_names["main"]
      })]
    }

    kube-prometheus-stack = {
      name       = "kube-prometheus-stack"
      repository = "oci://ghcr.io/prometheus-community/charts"
      chart      = "kube-prometheus-stack"
      version    = "92.11.0"
      namespace  = "monitoring"
      timeout    = 600
      values = [templatefile("${get_terragrunt_dir()}/values/kube-prometheus-stack.yaml", {
        domain = local.env.domain
      })]
    }

    loki = {
      name       = "loki"
      repository = "https://grafana.github.io/helm-charts"
      chart      = "loki"
      version    = "7.5.0"
      namespace  = "logging"
      timeout    = 600
      values = [templatefile("${get_terragrunt_dir()}/values/loki.yaml", {
        region = local.env.region
        bucket = dependency.s3.outputs.bucket_names["loki"]
      })]
    }

    alloy = {
      name       = "alloy"
      repository = "https://grafana.github.io/helm-charts"
      chart      = "alloy"
      version    = "1.14.2"
      namespace  = "logging"
      values = [templatefile("${get_terragrunt_dir()}/values/alloy.yaml", {
        cluster = dependency.eks.outputs.cluster_names["main"]
      })]
    }

    argo-cd = {
      name       = "argo-cd"
      repository = "https://argoproj.github.io/argo-helm"
      chart      = "argo-cd"
      version    = "10.10.5"
      namespace  = "argocd"
      values = [templatefile("${get_terragrunt_dir()}/values/argo-cd.yaml", {
        domain = local.env.domain
      })]
    }

    argo-rollouts = {
      name       = "argo-rollouts"
      repository = "https://argoproj.github.io/argo-helm"
      chart      = "argo-rollouts"
      version    = "2.43.8"
      namespace  = "argo-rollouts"
      values     = [file("${get_terragrunt_dir()}/values/argo-rollouts.yaml")]
    }
  }

  # The GitOps repo is private; Argo CD reads it with the credentials synced by ESO.
  manifests = {
    secretstore-argocd = templatefile("${get_terragrunt_dir()}/manifests/secretstore-argocd.yaml", {
      region = local.env.region
    })
    externalsecret-gitops-repo = templatefile("${get_terragrunt_dir()}/manifests/externalsecret-gitops-repo.yaml", {
      repo_url    = "https://github.com/mohamedsheriif/shopflow-gitops.git"
      secret_name = "${local.env.project}/${local.env.env}/argocd/gitops-repo"
    })

    argocd-root-app = templatefile("${get_terragrunt_dir()}/manifests/argocd-root-app.yaml", {
      repo_url = "https://github.com/mohamedsheriif/shopflow-gitops.git"
      revision = "main"
      path     = "clusters/${local.env.env}"
    })
  }
}
