data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  azs = slice(data.aws_availability_zones.available.names, 0, 2)
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 6.0"

  name = "${var.cluster_name}-vpc"
  cidr = "10.42.0.0/16"

  azs            = local.azs
  public_subnets = ["10.42.1.0/24", "10.42.2.0/24"]

  enable_nat_gateway = false
  enable_vpn_gateway = false

  map_public_ip_on_launch = true
  enable_dns_hostnames    = true
  enable_dns_support      = true

  public_subnet_tags = {
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
    "kubernetes.io/role/elb"                    = "1"
  }

  tags = var.tags
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 21.0"

  name               = var.cluster_name
  kubernetes_version = null

  endpoint_public_access = true

  enable_cluster_creator_admin_permissions = true

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.public_subnets

  addons = {
    coredns = {
      most_recent = true
    }
    kube-proxy = {
      most_recent = true
    }
    vpc-cni = {
      most_recent = true
    }
    amazon-cloudwatch-observability = {
      most_recent = true
    }
  }

  eks_managed_node_groups = {
    learning = {
      name           = "mng-public-learning"
      instance_types = [var.node_instance_type]

      min_size     = 1
      max_size     = 3
      desired_size = 2

      disk_size = 20
    }
  }

  tags = var.tags
}
