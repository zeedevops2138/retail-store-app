locals {
  security_groups_active = !var.opentelemetry_enabled
  cluster_name           = var.environment_name
}

module "tags" {
  source = "../../lib/tags"

  environment_name = var.environment_name
}

module "vpc" {
  source = "../../lib/vpc"

  environment_name = var.environment_name

  public_subnet_tags = {
    "kubernetes.io/cluster/${local.cluster_name}" = "shared"
    "kubernetes.io/role/elb"                     = 1
  }

  private_subnet_tags = {
    "kubernetes.io/cluster/${local.cluster_name}" = "shared"
    "kubernetes.io/role/internal-elb"            = 1
  }

  tags = module.tags.result
}

module "dependencies" {
  source = "../../lib/dependencies"

  environment_name = var.environment_name
  tags             = module.tags.result

  vpc_id     = module.vpc.inner.vpc_id
  subnet_ids = module.vpc.inner.private_subnets

  catalog_security_group_id  = local.security_groups_active ? aws_security_group.catalog.id : module.retail_app_eks.node_security_group_id
  orders_security_group_id   = local.security_groups_active ? aws_security_group.orders.id : module.retail_app_eks.node_security_group_id
  checkout_security_group_id = local.security_groups_active ? aws_security_group.checkout.id : module.retail_app_eks.node_security_group_id
}

module "retail_app_eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.31"

  cluster_name    = local.cluster_name
  cluster_version = "1.33"

  # Enable public access
  cluster_endpoint_public_access = true

  # Enable cluster creator admin permissions
  enable_cluster_creator_admin_permissions = true

  # EKS Auto Mode configuration
  cluster_compute_config = {
    enabled    = true
    node_pools = ["general-purpose"]
  }

  # Networking
  vpc_id     = module.vpc.inner.vpc_id
  subnet_ids = module.vpc.inner.private_subnets

  # Tags
  tags = {
    Environment = var.environment_name
    Terraform   = "true"
  }

  # Optional: Add additional cluster settings
  cluster_additional_security_group_ids = [
    module.dependencies.security_group_id
  ]
}
