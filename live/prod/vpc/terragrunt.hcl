include "root" {
  path = find_in_parent_folders("root.hcl")
}

locals {
  env = read_terragrunt_config(find_in_parent_folders("env.hcl")).locals
}

terraform {
  source = "${get_repo_root()}/modules/vpc"
}

dependency "s3_logs" {
  config_path = "../s3-logs"

  mock_outputs = {
    bucket_arns = { logs = "arn:aws:s3:::shopflow-prod-logs-222222222222" }
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan"]
}

inputs = {
  project = local.env.project
  env     = local.env.env
  tags    = local.env.tags

  # 10.20.0.0/16 doesn't overlap dev's 10.10.0.0/16, so both Tailscale routers can
  # advertise their VPC to the same tailnet.
  vpc = {
    main = {
      name                    = "${local.env.project}-${local.env.env}"
      create_igw              = true
      cidr_block              = "10.20.0.0/16"
      flow_logs_enabled       = true
      flow_logs_s3_bucket_arn = dependency.s3_logs.outputs.bucket_arns["logs"]
    }
  }

  # A regional NAT Gateway spans every AZ, so losing one AZ doesn't cut egress for the others.
  nat = {
    main = {
      availability_mode = "regional"
      vpc_key           = "main"
    }
  }

  subnets = {
    # Public: ALBs and the Tailscale router.
    public-us-east-1a = {
      vpc_key           = "main"
      availability_zone = "us-east-1a"
      cidr_block        = "10.20.0.0/24"
      tags              = { "kubernetes.io/role/elb" = "1" }
    }
    public-us-east-1b = {
      vpc_key           = "main"
      availability_zone = "us-east-1b"
      cidr_block        = "10.20.1.0/24"
      tags              = { "kubernetes.io/role/elb" = "1" }
    }
    public-us-east-1c = {
      vpc_key           = "main"
      availability_zone = "us-east-1c"
      cidr_block        = "10.20.2.0/24"
      tags              = { "kubernetes.io/role/elb" = "1" }
    }

    # App: EKS nodes and pods. /19 per AZ leaves room for VPC CNI prefix delegation.
    # Karpenter launches nodes in subnets with the discovery tag.
    app-us-east-1a = {
      vpc_key           = "main"
      availability_zone = "us-east-1a"
      cidr_block        = "10.20.32.0/19"
      tags = {
        "kubernetes.io/role/internal-elb" = "1"
        "karpenter.sh/discovery"          = "${local.env.project}-${local.env.env}"
      }
    }
    app-us-east-1b = {
      vpc_key           = "main"
      availability_zone = "us-east-1b"
      cidr_block        = "10.20.64.0/19"
      tags = {
        "kubernetes.io/role/internal-elb" = "1"
        "karpenter.sh/discovery"          = "${local.env.project}-${local.env.env}"
      }
    }
    app-us-east-1c = {
      vpc_key           = "main"
      availability_zone = "us-east-1c"
      cidr_block        = "10.20.96.0/19"
      tags = {
        "kubernetes.io/role/internal-elb" = "1"
        "karpenter.sh/discovery"          = "${local.env.project}-${local.env.env}"
      }
    }

    # Private: RDS and ElastiCache. No route to the internet.
    private-us-east-1a = {
      vpc_key           = "main"
      availability_zone = "us-east-1a"
      cidr_block        = "10.20.10.0/24"
    }
    private-us-east-1b = {
      vpc_key           = "main"
      availability_zone = "us-east-1b"
      cidr_block        = "10.20.11.0/24"
    }
    private-us-east-1c = {
      vpc_key           = "main"
      availability_zone = "us-east-1c"
      cidr_block        = "10.20.12.0/24"
    }
  }

  route_tables = {
    public = {
      vpc_key     = "main"
      subnet_keys = ["public-us-east-1a", "public-us-east-1b", "public-us-east-1c"]
      use_igw     = true
      routes      = [{ cidr_block = "0.0.0.0/0" }]
    }
    app = {
      vpc_key     = "main"
      subnet_keys = ["app-us-east-1a", "app-us-east-1b", "app-us-east-1c"]
      use_nat     = true
      nat_key     = "main"
      routes      = [{ cidr_block = "0.0.0.0/0" }]
    }
    private = {
      vpc_key     = "main"
      subnet_keys = ["private-us-east-1a", "private-us-east-1b", "private-us-east-1c"]
    }
  }

  vpc_endpoints = {
    s3 = {
      vpc_key          = "main"
      service_name     = "com.amazonaws.${local.env.region}.s3"
      route_table_keys = ["app"]
    }
  }
}
