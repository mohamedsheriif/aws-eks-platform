include "root" {
  path = find_in_parent_folders("root.hcl")
}

locals {
  env = read_terragrunt_config(find_in_parent_folders("env.hcl")).locals
}

terraform {
  source = "${get_repo_root()}/modules/vpc"
}

inputs = {
  project = local.env.project
  env     = local.env.env
  tags    = local.env.tags

  vpc = {
    main = {
      name       = "${local.env.project}-${local.env.env}"
      create_igw = true
      cidr_block = "10.10.0.0/16"
    }
  }

  # One zonal NAT Gateway in dev to keep cost down.
  eip = {
    nat = {}
  }

  nat = {
    main = {
      availability_mode = "zonal"
      eip_key           = "nat"
      subnet_key        = "public-us-east-1a"
    }
  }

  subnets = {
    # Public: ALB, NAT Gateway, Tailscale router.
    public-us-east-1a = {
      vpc_key           = "main"
      availability_zone = "us-east-1a"
      cidr_block        = "10.10.0.0/24"
      tags              = { "kubernetes.io/role/elb" = "1" }
    }
    public-us-east-1b = {
      vpc_key           = "main"
      availability_zone = "us-east-1b"
      cidr_block        = "10.10.1.0/24"
      tags              = { "kubernetes.io/role/elb" = "1" }
    }

    # App: EKS nodes and pods. /19 per AZ leaves room for VPC CNI prefix delegation.
    app-us-east-1a = {
      vpc_key           = "main"
      availability_zone = "us-east-1a"
      cidr_block        = "10.10.32.0/19"
      tags = {
        "kubernetes.io/role/internal-elb" = "1"
        "karpenter.sh/discovery"          = "${local.env.project}-${local.env.env}"
      }
    }
    app-us-east-1b = {
      vpc_key           = "main"
      availability_zone = "us-east-1b"
      cidr_block        = "10.10.64.0/19"
      tags = {
        "kubernetes.io/role/internal-elb" = "1"
        "karpenter.sh/discovery"          = "${local.env.project}-${local.env.env}"
      }
    }

    # Private: RDS and ElastiCache. No route to the internet.
    private-us-east-1a = {
      vpc_key           = "main"
      availability_zone = "us-east-1a"
      cidr_block        = "10.10.10.0/24"
    }
    private-us-east-1b = {
      vpc_key           = "main"
      availability_zone = "us-east-1b"
      cidr_block        = "10.10.11.0/24"
    }
  }

  route_tables = {
    public = {
      vpc_key     = "main"
      subnet_keys = ["public-us-east-1a", "public-us-east-1b"]
      use_igw     = true
      routes      = [{ cidr_block = "0.0.0.0/0" }]
    }
    app = {
      vpc_key     = "main"
      subnet_keys = ["app-us-east-1a", "app-us-east-1b"]
      use_nat     = true
      nat_key     = "main"
      routes      = [{ cidr_block = "0.0.0.0/0" }]
    }
    private = {
      vpc_key     = "main"
      subnet_keys = ["private-us-east-1a", "private-us-east-1b"]
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
