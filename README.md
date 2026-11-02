# ShopFlow on AWS EKS

## Overview

Infrastructure for **ShopFlow**, an e-commerce application made of five microservices running on Amazon EKS.
Everything is defined as code with **Terraform modules and Terragrunt**: the network, a private Kubernetes cluster,
managed data services, and the in-cluster platform that delivers and observes the services.

Dev and prod each have their own AWS account and share the same modules; prod adds high availability,
Spot capacity with Karpenter, WAF and full logging. The whole stack can be planned locally, without an AWS account.

## Architecture

```mermaid
flowchart LR
  user([Users])
  eng([Engineers])

  user --> waf{{WAF in prod}}
  waf --> cf[CloudFront] --> s3a[(S3 assets)]
  waf --> palb

  eng -- Tailscale --> ts

  subgraph VPC["VPC · 2 AZs in dev, 3 in prod"]
    subgraph public[Public subnets]
      palb[Public ALB]
      ts[Tailscale router]
      nat[NAT gateway]
    end
    subgraph app[App subnets]
      ialb[Internal ALB]
      eks[EKS<br/>managed node groups<br/>+ Karpenter Spot in prod]
    end
    subgraph private[Private subnets]
      rds[(PostgreSQL)]
      valkey[(Valkey)]
    end
  end

  palb --> eks
  ts --> ialb --> eks
  ts --> eks
  eks --> rds & valkey
  eks --> nat
  eks -.-> svc[SQS · SES · S3 · Secrets Manager]
```

**How traffic flows**

- **Static assets:** users → CloudFront (HTTP/3, TLS) → private S3 bucket through Origin Access Control.
- **API requests:** users → public ALB (TLS 1.2+, ACM certificate) → service pods → PostgreSQL and Valkey,
  authenticated with IAM tokens over TLS.
- **Events:** orders and payments publish to SQS; the notifications service consumes them and sends email through SES.
- **Engineers:** Tailscale → subnet router → private EKS API, internal ALB (Argo CD, Grafana) and databases.
  Nothing operational is exposed to the internet.

## Tech stack

| Area | Tools |
|---|---|
| IaC | Terraform 1.13, Terragrunt 0.90, AWS provider 6.38 |
| Compute | EKS 1.34, managed node groups and Karpenter on Graviton (arm64), AL2023 |
| Networking | VPC, ALB, NAT gateway, Route53, CloudFront, ACM, WAF, Tailscale |
| Data | RDS PostgreSQL 17, ElastiCache Valkey 8, S3, SQS, SES |
| Security | KMS, Secrets Manager, IAM, EKS Pod Identity, External Secrets |
| Delivery | Argo CD, Argo Rollouts, Helm |
| Observability | Prometheus, Grafana, Loki, Alloy |

## Key features

### Security

- **Private Kubernetes API.** The EKS endpoint has no public access; it is reached over a Tailscale subnet router
  that has no inbound ports.
- **No static credentials.** Every workload uses EKS Pod Identity, trusted only for this account and cluster.
  Node IMDS is limited to hop count 1, so pods can't use the node's credentials.
- **Passwordless databases.** Services connect to PostgreSQL and Valkey with short-lived IAM tokens.
  The RDS master password is generated and stored by RDS.
- **Least privilege per service.** Each microservice gets its own role, database user and resources:

  | Service | PostgreSQL | Valkey keys | S3 | SQS | SES |
  |---|---|---|---|---|---|
  | catalog | ✓ | `catalog:*` | `assets/products/*` | | |
  | users | ✓ | | `data/users/*` | | |
  | orders | ✓ | `orders:*` | | send | |
  | payments | ✓ | | | send | |
  | notifications | | | | consume | send |

- **Encryption at rest.** A customer-managed KMS key per service (EKS secrets, EBS, RDS, ElastiCache, S3, SQS,
  Secrets Manager), rotated every 90 days.
- **Encryption in transit.** TLS 1.2+ on CloudFront and the ALBs (TLS 1.3 policy), `rds.force_ssl`,
  TLS-required Valkey, and bucket and queue policies that deny non-TLS requests.
- **Secrets stay out of Terraform state.** Secrets are created empty, filled outside Terraform, and synced into
  Kubernetes by External Secrets through namespaced SecretStores.
- **WAF in prod.** CloudFront and the public ALB are behind AWS managed rule groups (IP reputation, common
  exploits, known bad inputs, SQL injection on the API) and a per-IP rate limit.
- **MFA-protected cluster access.** IAM groups assume an admin or a read-only role, mapped through EKS access entries.
  The cluster creator gets no implicit admin.

### Networking

- Three subnet tiers across two AZs in dev and three in prod: **public** (ALB, NAT, router), **app** (nodes and
  pods, /19 per AZ for VPC CNI prefix delegation) and **private** (databases, no internet route).
- Dev uses `10.10.0.0/16` and prod `10.20.0.0/16`, so both Tailscale routers share one tailnet.
- Two IngressClasses: **`alb-public`** is internet-facing and only usable from the `apps` namespace;
  **`alb-internal`** serves platform UIs over Tailscale.
- external-dns manages records for each Ingress in the environment's zone.
- An S3 gateway endpoint keeps S3 traffic off the NAT gateway.

### Platform & GitOps

- Platform components are installed by Terraform in two stages: **`helm-core`** (ALB controller, External Secrets,
  Prometheus CRDs, IngressClasses, encrypted gp3 StorageClass), then **`helm-platform`**, which depends on it.
- Argo CD runs an **app of apps** that syncs the microservices from a private GitOps repository, with credentials
  synced from Secrets Manager.
- Argo Rollouts enables canary and blue-green releases.
- **Karpenter in prod** adds Spot nodes for application pods on top of an on-demand baseline, and drains nodes
  ahead of Spot interruptions using EventBridge events delivered through SQS.

### Observability

- **Metrics:** kube-prometheus-stack, with Prometheus picking up ServiceMonitors from every namespace.
- **Logs:** Alloy on every node ships container logs to Loki, which runs in simple scalable mode on S3.
- **Dashboards:** Grafana with Prometheus and Loki data sources, admin credentials from Secrets Manager.
- **Audit trail in prod:** EKS control plane logs, PostgreSQL logs, VPC flow logs, and ALB and CloudFront access
  logs.

### Cost optimization

- Graviton instances everywhere: EKS nodes, RDS, ElastiCache and the Tailscale router.
- Dev runs one NAT gateway and single-AZ data services, with chart resources sized to fit one system node.
- Prod scales application capacity on Spot through Karpenter, which also consolidates underused nodes.
- S3 buckets use Bucket Keys, which cuts KMS request costs.

## Project structure

```
.
├── .github/               CI/CD workflows and a shared setup action
├── modules/               One Terraform module per AWS service
├── scripts/
│   ├── bootstrap.sh       One-time account setup: state bucket and CI roles
│   └── scan-plans.sh      Trivy scan of each unit's plan, as one SARIF report
└── live/
    ├── dev/
    │   ├── env.hcl        Project, account, region, domain and tags
    │   ├── root.hcl       S3 backend and AWS provider
    │   ├── root-helm.hcl  Same, plus the helm and kubectl providers
    │   └── <unit>/        One Terragrunt unit per stack
    └── prod/              Same layout, with prod values and three extra units
```

Each module creates its resources with `for_each` over a map, so the same module serves one resource or many.
Units keep their configuration inline and declare their dependencies, which also sets the apply order.

| Unit | Creates |
|---|---|
| `github-oidc` | GitHub OIDC provider, plan role for pull requests and `main`, apply role for the environment |
| `kms` | One KMS key per service |
| `vpc` | VPC, subnets, route tables, NAT gateway, S3 endpoint |
| `security-groups` | Tailscale router and EKS API security groups |
| `route53`, `acm` | Hosted zone and wildcard certificate (prod's `shopflow.com` delegates `dev.shopflow.com`) |
| `cloudfront`, `s3` | Assets distribution, assets, data and Loki buckets |
| `sqs`, `ses` | Notifications queue with DLQ, SES domain identity with DKIM |
| `iam-roles` | EKS, node, controller and Tailscale roles |
| `iam-roles-apps` | One Pod Identity role per microservice |
| `iam-groups` | Admins and developers groups |
| `eks` | Cluster, node groups, add-ons, access entries, Pod Identity associations |
| `security-groups-data` | PostgreSQL and Valkey security groups |
| `rds`, `elasticache` | PostgreSQL and Valkey |
| `secrets-manager` | Secrets for the router, Grafana, Argo CD and each microservice |
| `tailscale` | Tailscale subnet router |
| `helm-core` | Controllers, CRDs and cluster-wide objects |
| `helm-platform` | DNS, monitoring, logging and delivery |
| `s3-logs` (prod) | Logs bucket for flow logs and ALB and CloudFront access logs |
| `waf` (prod) | Web ACLs for CloudFront and the public ALB |
| `eventbridge` (prod) | Spot interruption and instance events for Karpenter |

## Environments

| | dev | prod |
|---|---|---|
| Availability zones | 2 | 3 |
| NAT gateway | One zonal | Regional |
| Nodes | 1 system + 1 apps, t4g.medium | 2 system + 2 apps, t4g.large, plus Karpenter on Spot |
| PostgreSQL | db.t4g.micro, single-AZ, 1-day backups | db.t4g.medium, Multi-AZ, 14-day backups, Performance Insights |
| Valkey | cache.t4g.micro, one node | cache.t4g.small, primary + replica with automatic failover |
| WAF | Off | CloudFront and public ALB |
| Logs | None | EKS control plane, PostgreSQL, VPC flow, ALB and CloudFront access logs |
| Deletion protection, S3 versioning | Off | On |
| KMS deletion window / secret recovery | 7 / 0 days | 30 / 30 days |
| Prometheus / Loki retention | 7 / 14 days | 15 / 30 days |
| Platform replicas | 1 | 2 for controllers, Argo CD and Loki; Alertmanager on |

## Deployment

### Prerequisites

- Terraform ≥ 1.10, Terragrunt 0.90, AWS CLI v2, kubectl
- An AWS CLI profile per environment (`shopflow-dev`, `shopflow-prod`) with MFA
- A Tailscale account

### Bootstrap (once per environment)

One script prepares a new account: it creates the Terraform state bucket (versioned, encrypted, public access
blocked, TLS only), then applies `github-oidc` so GitHub Actions can plan and apply without stored AWS keys.
It checks that the profile points at the account in `env.hcl` and is safe to re-run.

```bash
./scripts/bootstrap.sh dev    # or prod
```

### Plan locally, without AWS

`TG_MOCK=true` switches every unit to local state, fake credentials and mocked dependency outputs:

```bash
cd live/dev                   # or live/prod
TG_MOCK=true terragrunt run --all plan
```

### Apply

The commands use dev; for prod, run them in `live/prod` with the `shopflow-prod` names.

```bash
cd live/dev

# 1. KMS keys and empty secrets
terragrunt run --all apply --queue-include-dir secrets-manager

# 2. Fill in the secrets (Post-deployment, step 1)

# 3. All AWS infrastructure
terragrunt run --all apply --queue-exclude-dir 'helm-*'

# 4. In-cluster platform, from the tailnet (Post-deployment, steps 2 and 3)
aws eks update-kubeconfig --name shopflow-dev --region us-east-1 --profile shopflow-dev \
  --role-arn arn:aws:iam::<account-id>:role/shopflow-dev-eks-admin
terragrunt run --all apply --queue-include-dir 'helm-*' --queue-strict-include
```

## Post-deployment

1. **Secrets.** Set the values before steps 3 and 4:

   | Secret | Value |
   |---|---|
   | `shopflow/dev/tailscale/auth-key` | Reusable, pre-approved Tailscale auth key |
   | `shopflow/dev/grafana/admin` | `{"username": "...", "password": "..."}` |
   | `shopflow/dev/argocd/gitops-repo` | `{"username": "...", "password": "<read-only GitHub token>"}` |
   | `shopflow/dev/<service>/env` | JSON of the service's sensitive environment variables |

   ```bash
   aws secretsmanager put-secret-value --secret-id shopflow/dev/tailscale/auth-key --secret-string '<key>'
   ```

2. **Tailscale.** Approve the advertised route (`10.10.0.0/16` for `shopflow-dev-router`, `10.20.0.0/16` for
   `shopflow-prod-router`), and add the VPC resolver (`10.10.0.2` or `10.20.0.2`) as a split-DNS nameserver for
   `us-east-1.eks.amazonaws.com`, `rds.amazonaws.com`, `cache.amazonaws.com` and the environment's domain.

3. **Cluster access.** Add your IAM user to `shopflow-dev-admins` (or `shopflow-dev-developers` for read-only).
   The group can assume the matching EKS role, which requires MFA.

4. **Database users.** Connect as the master user (credentials in the RDS-managed secret) and run:

   ```sql
   CREATE USER catalog;  GRANT rds_iam TO catalog;
   CREATE USER users;    GRANT rds_iam TO users;
   CREATE USER orders;   GRANT rds_iam TO orders;
   CREATE USER payments; GRANT rds_iam TO payments;
   ```

5. **Access the platform** (over Tailscale):

   | | URL | Login |
   |---|---|---|
   | Argo CD | https://argocd.dev.shopflow.com, https://argocd.shopflow.com | `admin`, password in the `argocd-initial-admin-secret` Secret |
   | Grafana | https://grafana.dev.shopflow.com, https://grafana.shopflow.com | From `shopflow/<env>/grafana/admin` |

   For the Argo CD CLI: `argocd login argocd.dev.shopflow.com --grpc-web`.

6. **Prod only.** Replace the placeholder dev name servers in `live/prod/route53` with the output of
   `terragrunt output name_servers` in `live/dev/route53`, and add an Alertmanager receiver (Slack, PagerDuty)
   to the kube-prometheus-stack values.

## CI/CD

GitHub Actions, authenticated to AWS through OIDC (no stored keys):

| Workflow | Trigger | Jobs |
|---|---|---|
| [`ci.yml`](.github/workflows/ci.yml) | Pull request, push to `main` | **Format** (`terraform fmt`, `terragrunt hcl fmt`) and **Lint** (TFLint with the AWS ruleset) in parallel, then **Plan** per environment, with each unit's plan scanned by **Trivy** |
| [`cd.yml`](.github/workflows/cd.yml) | Push to `main` | **Apply** dev, then prod if dev succeeded, each inside a GitHub environment that can require approval |

- **Mock until AWS exists.** While the repository variable `AWS_DEPLOY_ENABLED` isn't `true`, plans run with
  `TG_MOCK=true` and apply is skipped. Setting it switches to real plans and applies.
- **Security scan of the plan.** Trivy checks every unit's plan for AWS misconfigurations. Findings appear in
  the job summary and the Security tab, linked to the unit, and don't block the build.
- **Caching.** Terragrunt's provider cache (keyed on the lock files), Helm charts, the Terragrunt binary
  and TFLint plugins are cached, so only changed inputs are downloaded.
- **Safe applies.** One apply per environment at a time, actions pinned to commit SHAs, and least-privilege
  job permissions.
- **In-cluster units** (`helm-*`) are applied from the tailnet, since the EKS API is private.

## Roadmap

**Account security**
- [ ] CloudTrail: an organization trail for every API call, with log file validation, in a dedicated audit bucket
- [ ] GuardDuty: threat detection with S3, EKS audit log, EKS runtime and RDS login protection
- [ ] AWS Config: resource history and managed rules for the settings this platform relies on
- [ ] Security Hub: one place for findings from GuardDuty, AWS Config and IAM Access Analyzer
- [ ] IAM Access Analyzer: flag resources shared outside the account
- [ ] AWS Budgets: cost alerts per environment

**Kubernetes security**
- [ ] Policy as code with Kyverno: block privileged pods, require resource limits and trusted registries
- [ ] Image scanning and signing: ECR scan on push, cosign signatures verified at admission
- [ ] Network policies with the VPC CNI to restrict traffic between namespaces

**Delivery**
- [ ] Renovate for actions, providers, charts and tool versions
- [ ] Plans posted as pull request comments
- [ ] Tailscale in CI, so the in-cluster units are planned and applied from GitHub Actions
