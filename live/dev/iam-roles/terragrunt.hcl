include "root" {
  path = find_in_parent_folders("root.hcl")
}

locals {
  env = read_terragrunt_config(find_in_parent_folders("env.hcl")).locals
}

terraform {
  source = "${get_repo_root()}/modules/iam-roles"
}

dependency "kms" {
  config_path = "../kms"

  mock_outputs = {
    kms_key_arns = {
      eks     = "arn:aws:kms:us-east-1:111111111111:key/mock-eks"
      ebs     = "arn:aws:kms:us-east-1:111111111111:key/mock-ebs"
      s3      = "arn:aws:kms:us-east-1:111111111111:key/mock-s3"
      secrets = "arn:aws:kms:us-east-1:111111111111:key/mock-secrets"
    }
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

inputs = {
  project = local.env.project
  env     = local.env.env
  tags    = local.env.tags

  roles = {
    eks-cluster = {
      name        = "${local.env.project}-${local.env.env}-eks-cluster"
      description = "EKS control plane"
      service     = "eks.amazonaws.com"
      policy_arns = ["arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"]
      inline_policies = {
        secrets-encryption = jsonencode({
          Version = "2012-10-17"
          Statement = [{
            Effect   = "Allow"
            Action   = ["kms:Encrypt", "kms:Decrypt", "kms:DescribeKey", "kms:ListGrants"]
            Resource = dependency.kms.outputs.kms_key_arns["eks"]
          }]
        })
      }
    }

    # Managed node groups (system and apps). The CNI permissions go to the
    # vpc-cni Pod Identity role instead of the node.
    eks-node = {
      name        = "${local.env.project}-${local.env.env}-eks-node"
      description = "EKS managed node groups"
      service     = "ec2.amazonaws.com"
      policy_arns = [
        "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy",
        "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryPullOnly",
        "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore",
      ]
    }

    # Assumed by the admins group; mapped to cluster admin by an EKS access entry.
    eks-admin = {
      name                   = "${local.env.project}-${local.env.env}-eks-admin"
      description            = "EKS cluster administrators"
      trusted_entity         = ["arn:aws:iam::${local.env.account_id}:root"]
      assume_role_conditions = { Bool = { "aws:MultiFactorAuthPresent" = "true" } }
      inline_policies = {
        eks-access = jsonencode({
          Version = "2012-10-17"
          Statement = [{
            Effect   = "Allow"
            Action   = "eks:DescribeCluster"
            Resource = "arn:aws:eks:${local.env.region}:${local.env.account_id}:cluster/${local.env.project}-${local.env.env}"
          }]
        })
      }
    }

    # Assumed by the developers group; mapped to read-only cluster access by an EKS access entry.
    eks-developer = {
      name                   = "${local.env.project}-${local.env.env}-eks-developer"
      description            = "EKS read-only access for developers"
      trusted_entity         = ["arn:aws:iam::${local.env.account_id}:root"]
      assume_role_conditions = { Bool = { "aws:MultiFactorAuthPresent" = "true" } }
      inline_policies = {
        eks-access = jsonencode({
          Version = "2012-10-17"
          Statement = [{
            Effect   = "Allow"
            Action   = "eks:DescribeCluster"
            Resource = "arn:aws:eks:${local.env.region}:${local.env.account_id}:cluster/${local.env.project}-${local.env.env}"
          }]
        })
      }
    }

    vpc-cni = {
      name                = "${local.env.project}-${local.env.env}-vpc-cni"
      description         = "kube-system/aws-node"
      service             = "pods.eks.amazonaws.com"
      assume_role_actions = ["sts:AssumeRole", "sts:TagSession"]
      assume_role_conditions = {
        StringEquals = { "aws:SourceAccount" = local.env.account_id }
        ArnEquals    = { "aws:SourceArn" = "arn:aws:eks:${local.env.region}:${local.env.account_id}:cluster/${local.env.project}-${local.env.env}" }
      }
      policy_arns = ["arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"]
    }

    ebs-csi = {
      name                = "${local.env.project}-${local.env.env}-ebs-csi"
      description         = "kube-system/ebs-csi-controller-sa"
      service             = "pods.eks.amazonaws.com"
      assume_role_actions = ["sts:AssumeRole", "sts:TagSession"]
      assume_role_conditions = {
        StringEquals = { "aws:SourceAccount" = local.env.account_id }
        ArnEquals    = { "aws:SourceArn" = "arn:aws:eks:${local.env.region}:${local.env.account_id}:cluster/${local.env.project}-${local.env.env}" }
      }
      policy_arns = ["arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"]
      # The managed policy doesn't cover customer managed keys; the gp3 StorageClass uses the ebs key.
      inline_policies = {
        ebs-kms = jsonencode({
          Version = "2012-10-17"
          Statement = [
            {
              Sid       = "Grants"
              Effect    = "Allow"
              Action    = ["kms:CreateGrant", "kms:ListGrants", "kms:RevokeGrant"]
              Resource  = dependency.kms.outputs.kms_key_arns["ebs"]
              Condition = { Bool = { "kms:GrantIsForAWSResource" = "true" } }
            },
            {
              Sid       = "Volumes"
              Effect    = "Allow"
              Action    = ["kms:Encrypt", "kms:Decrypt", "kms:ReEncrypt*", "kms:GenerateDataKey*", "kms:DescribeKey"]
              Resource  = dependency.kms.outputs.kms_key_arns["ebs"]
              Condition = { StringEquals = { "kms:ViaService" = "ec2.${local.env.region}.amazonaws.com" } }
            },
          ]
        })
      }
    }

    # Permissions follow the AWS Load Balancer Controller reference policy; mutations
    # are limited to resources tagged with elbv2.k8s.aws/cluster.
    aws-load-balancer-controller = {
      name                = "${local.env.project}-${local.env.env}-aws-load-balancer-controller"
      description         = "kube-system/aws-load-balancer-controller"
      service             = "pods.eks.amazonaws.com"
      assume_role_actions = ["sts:AssumeRole", "sts:TagSession"]
      assume_role_conditions = {
        StringEquals = { "aws:SourceAccount" = local.env.account_id }
        ArnEquals    = { "aws:SourceArn" = "arn:aws:eks:${local.env.region}:${local.env.account_id}:cluster/${local.env.project}-${local.env.env}" }
      }
      inline_policies = {
        aws-load-balancer-controller = jsonencode({
          Version = "2012-10-17"
          Statement = [
            {
              Effect    = "Allow"
              Action    = "iam:CreateServiceLinkedRole"
              Resource  = "*"
              Condition = { StringEquals = { "iam:AWSServiceName" = "elasticloadbalancing.amazonaws.com" } }
            },
            {
              # Read-only discovery calls; these APIs have no resource-level permissions.
              Effect = "Allow"
              Action = [
                "ec2:DescribeAccountAttributes",
                "ec2:DescribeAddresses",
                "ec2:DescribeAvailabilityZones",
                "ec2:DescribeInternetGateways",
                "ec2:DescribeVpcs",
                "ec2:DescribeVpcPeeringConnections",
                "ec2:DescribeSubnets",
                "ec2:DescribeSecurityGroups",
                "ec2:DescribeInstances",
                "ec2:DescribeNetworkInterfaces",
                "ec2:DescribeTags",
                "ec2:DescribeRouteTables",
                "ec2:GetCoipPoolUsage",
                "ec2:DescribeCoipPools",
                "ec2:GetSecurityGroupsForVpc",
                "ec2:DescribeIpamPools",
                "elasticloadbalancing:DescribeLoadBalancers",
                "elasticloadbalancing:DescribeLoadBalancerAttributes",
                "elasticloadbalancing:DescribeListeners",
                "elasticloadbalancing:DescribeListenerCertificates",
                "elasticloadbalancing:DescribeListenerAttributes",
                "elasticloadbalancing:DescribeSSLPolicies",
                "elasticloadbalancing:DescribeRules",
                "elasticloadbalancing:DescribeTargetGroups",
                "elasticloadbalancing:DescribeTargetGroupAttributes",
                "elasticloadbalancing:DescribeTargetHealth",
                "elasticloadbalancing:DescribeTags",
                "elasticloadbalancing:DescribeTrustStores",
                "elasticloadbalancing:DescribeCapacityReservation",
                "acm:ListCertificates",
                "acm:DescribeCertificate",
              ]
              Resource = "*"
            },
            {
              Effect   = "Allow"
              Action   = ["ec2:AuthorizeSecurityGroupIngress", "ec2:RevokeSecurityGroupIngress", "ec2:CreateSecurityGroup"]
              Resource = "*"
            },
            {
              Effect   = "Allow"
              Action   = "ec2:CreateTags"
              Resource = "arn:aws:ec2:${local.env.region}:${local.env.account_id}:security-group/*"
              Condition = {
                StringEquals = { "ec2:CreateAction" = "CreateSecurityGroup" }
                Null         = { "aws:RequestTag/elbv2.k8s.aws/cluster" = "false" }
              }
            },
            {
              Effect   = "Allow"
              Action   = ["ec2:CreateTags", "ec2:DeleteTags"]
              Resource = "arn:aws:ec2:${local.env.region}:${local.env.account_id}:security-group/*"
              Condition = {
                Null = {
                  "aws:RequestTag/elbv2.k8s.aws/cluster"  = "true"
                  "aws:ResourceTag/elbv2.k8s.aws/cluster" = "false"
                }
              }
            },
            {
              Effect    = "Allow"
              Action    = ["ec2:AuthorizeSecurityGroupIngress", "ec2:RevokeSecurityGroupIngress", "ec2:DeleteSecurityGroup"]
              Resource  = "*"
              Condition = { Null = { "aws:ResourceTag/elbv2.k8s.aws/cluster" = "false" } }
            },
            {
              Effect    = "Allow"
              Action    = ["elasticloadbalancing:CreateLoadBalancer", "elasticloadbalancing:CreateTargetGroup"]
              Resource  = "*"
              Condition = { Null = { "aws:RequestTag/elbv2.k8s.aws/cluster" = "false" } }
            },
            {
              Effect = "Allow"
              Action = [
                "elasticloadbalancing:CreateListener",
                "elasticloadbalancing:DeleteListener",
                "elasticloadbalancing:CreateRule",
                "elasticloadbalancing:DeleteRule",
              ]
              Resource = "*"
            },
            {
              Effect = "Allow"
              Action = ["elasticloadbalancing:AddTags", "elasticloadbalancing:RemoveTags"]
              Resource = [
                "arn:aws:elasticloadbalancing:${local.env.region}:${local.env.account_id}:targetgroup/*/*",
                "arn:aws:elasticloadbalancing:${local.env.region}:${local.env.account_id}:loadbalancer/net/*/*",
                "arn:aws:elasticloadbalancing:${local.env.region}:${local.env.account_id}:loadbalancer/app/*/*",
              ]
              Condition = {
                Null = {
                  "aws:RequestTag/elbv2.k8s.aws/cluster"  = "true"
                  "aws:ResourceTag/elbv2.k8s.aws/cluster" = "false"
                }
              }
            },
            {
              Effect = "Allow"
              Action = ["elasticloadbalancing:AddTags", "elasticloadbalancing:RemoveTags"]
              Resource = [
                "arn:aws:elasticloadbalancing:${local.env.region}:${local.env.account_id}:listener/net/*/*/*",
                "arn:aws:elasticloadbalancing:${local.env.region}:${local.env.account_id}:listener/app/*/*/*",
                "arn:aws:elasticloadbalancing:${local.env.region}:${local.env.account_id}:listener-rule/net/*/*/*",
                "arn:aws:elasticloadbalancing:${local.env.region}:${local.env.account_id}:listener-rule/app/*/*/*",
              ]
            },
            {
              Effect = "Allow"
              Action = [
                "elasticloadbalancing:ModifyLoadBalancerAttributes",
                "elasticloadbalancing:SetIpAddressType",
                "elasticloadbalancing:SetSecurityGroups",
                "elasticloadbalancing:SetSubnets",
                "elasticloadbalancing:DeleteLoadBalancer",
                "elasticloadbalancing:ModifyTargetGroup",
                "elasticloadbalancing:ModifyTargetGroupAttributes",
                "elasticloadbalancing:DeleteTargetGroup",
                "elasticloadbalancing:ModifyListenerAttributes",
                "elasticloadbalancing:ModifyCapacityReservation",
                "elasticloadbalancing:ModifyIpPools",
              ]
              Resource  = "*"
              Condition = { Null = { "aws:ResourceTag/elbv2.k8s.aws/cluster" = "false" } }
            },
            {
              Effect = "Allow"
              Action = "elasticloadbalancing:AddTags"
              Resource = [
                "arn:aws:elasticloadbalancing:${local.env.region}:${local.env.account_id}:targetgroup/*/*",
                "arn:aws:elasticloadbalancing:${local.env.region}:${local.env.account_id}:loadbalancer/net/*/*",
                "arn:aws:elasticloadbalancing:${local.env.region}:${local.env.account_id}:loadbalancer/app/*/*",
              ]
              Condition = {
                StringEquals = { "elasticloadbalancing:CreateAction" = ["CreateTargetGroup", "CreateLoadBalancer"] }
                Null         = { "aws:RequestTag/elbv2.k8s.aws/cluster" = "false" }
              }
            },
            {
              Effect   = "Allow"
              Action   = ["elasticloadbalancing:RegisterTargets", "elasticloadbalancing:DeregisterTargets"]
              Resource = "arn:aws:elasticloadbalancing:${local.env.region}:${local.env.account_id}:targetgroup/*/*"
            },
            {
              Effect = "Allow"
              Action = [
                "elasticloadbalancing:SetWebAcl",
                "elasticloadbalancing:ModifyListener",
                "elasticloadbalancing:AddListenerCertificates",
                "elasticloadbalancing:RemoveListenerCertificates",
                "elasticloadbalancing:ModifyRule",
                "elasticloadbalancing:SetRulePriorities",
              ]
              Resource = "*"
            },
          ]
        })
      }
    }

    external-dns = {
      name                = "${local.env.project}-${local.env.env}-external-dns"
      description         = "kube-system/external-dns"
      service             = "pods.eks.amazonaws.com"
      assume_role_actions = ["sts:AssumeRole", "sts:TagSession"]
      assume_role_conditions = {
        StringEquals = { "aws:SourceAccount" = local.env.account_id }
        ArnEquals    = { "aws:SourceArn" = "arn:aws:eks:${local.env.region}:${local.env.account_id}:cluster/${local.env.project}-${local.env.env}" }
      }
      inline_policies = {
        route53 = jsonencode({
          Version = "2012-10-17"
          Statement = [
            {
              Effect   = "Allow"
              Action   = ["route53:ChangeResourceRecordSets", "route53:ListResourceRecordSets"]
              Resource = "arn:aws:route53:::hostedzone/${dependency.route53.outputs.zone_ids["main"]}"
            },
            {
              # Zone discovery calls have no resource-level permissions.
              Effect   = "Allow"
              Action   = ["route53:ListHostedZones", "route53:ListTagsForResources"]
              Resource = "*"
            },
          ]
        })
      }
    }

    # External Secrets Operator: syncs secrets under <project>/<env>/ in Secrets Manager into Kubernetes Secrets.
    external-secrets = {
      name                = "${local.env.project}-${local.env.env}-external-secrets"
      description         = "external-secrets/external-secrets"
      service             = "pods.eks.amazonaws.com"
      assume_role_actions = ["sts:AssumeRole", "sts:TagSession"]
      assume_role_conditions = {
        StringEquals = { "aws:SourceAccount" = local.env.account_id }
        ArnEquals    = { "aws:SourceArn" = "arn:aws:eks:${local.env.region}:${local.env.account_id}:cluster/${local.env.project}-${local.env.env}" }
      }
      inline_policies = {
        secrets-read = jsonencode({
          Version = "2012-10-17"
          Statement = [
            {
              Effect   = "Allow"
              Action   = ["secretsmanager:GetSecretValue", "secretsmanager:DescribeSecret", "secretsmanager:ListSecretVersionIds"]
              Resource = "arn:aws:secretsmanager:${local.env.region}:${local.env.account_id}:secret:${local.env.project}/${local.env.env}/*"
            },
            {
              Effect    = "Allow"
              Action    = "kms:Decrypt"
              Resource  = dependency.kms.outputs.kms_key_arns["secrets"]
              Condition = { StringEquals = { "kms:ViaService" = "secretsmanager.${local.env.region}.amazonaws.com" } }
            },
          ]
        })
      }
    }

    # Tailscale subnet router (EC2). Reads its auth key at boot; SSM is the break-glass shell.
    tailscale = {
      name                    = "${local.env.project}-${local.env.env}-tailscale"
      description             = "Tailscale subnet router instance"
      service                 = "ec2.amazonaws.com"
      create_instance_profile = true
      policy_arns             = ["arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"]
      inline_policies = {
        auth-key = jsonencode({
          Version = "2012-10-17"
          Statement = [
            {
              Effect   = "Allow"
              Action   = "secretsmanager:GetSecretValue"
              Resource = "arn:aws:secretsmanager:${local.env.region}:${local.env.account_id}:secret:${local.env.project}/${local.env.env}/tailscale/*"
            },
            {
              Effect    = "Allow"
              Action    = "kms:Decrypt"
              Resource  = dependency.kms.outputs.kms_key_arns["secrets"]
              Condition = { StringEquals = { "kms:ViaService" = "secretsmanager.${local.env.region}.amazonaws.com" } }
            },
          ]
        })
      }
    }

    loki = {
      name                = "${local.env.project}-${local.env.env}-loki"
      description         = "logging/loki"
      service             = "pods.eks.amazonaws.com"
      assume_role_actions = ["sts:AssumeRole", "sts:TagSession"]
      assume_role_conditions = {
        StringEquals = { "aws:SourceAccount" = local.env.account_id }
        ArnEquals    = { "aws:SourceArn" = "arn:aws:eks:${local.env.region}:${local.env.account_id}:cluster/${local.env.project}-${local.env.env}" }
      }
      inline_policies = {
        s3 = jsonencode({
          Version = "2012-10-17"
          Statement = [
            {
              Effect   = "Allow"
              Action   = "s3:ListBucket"
              Resource = "arn:aws:s3:::${local.env.project}-${local.env.env}-loki-${local.env.account_id}"
            },
            {
              Effect   = "Allow"
              Action   = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
              Resource = "arn:aws:s3:::${local.env.project}-${local.env.env}-loki-${local.env.account_id}/*"
            },
            {
              Effect    = "Allow"
              Action    = ["kms:Decrypt", "kms:GenerateDataKey"]
              Resource  = dependency.kms.outputs.kms_key_arns["s3"]
              Condition = { StringEquals = { "kms:ViaService" = "s3.${local.env.region}.amazonaws.com" } }
            },
          ]
        })
      }
    }
  }
}
