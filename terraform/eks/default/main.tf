locals {
  cluster_name = var.environment_name
}

module "tags" {
  source           = "../../lib/tags"
  environment_name = var.environment_name
}

module "vpc" {
  source           = "../../lib/vpc"
  environment_name = var.environment_name
  public_subnet_tags = {
    "kubernetes.io/cluster/${local.cluster_name}" = "shared"
    "kubernetes.io/role/elb"                      = 1
  }
  private_subnet_tags = {
    "kubernetes.io/cluster/${local.cluster_name}" = "shared"
    "kubernetes.io/role/internal-elb"             = 1
  }
  tags = module.tags.result
}

module "retail_app_eks" {
  source                                   = "terraform-aws-modules/eks/aws"
  version                                  = "~> 20.31"
  cluster_name                             = local.cluster_name
  cluster_version                          = "1.33"
  cluster_endpoint_public_access           = true
  enable_cluster_creator_admin_permissions = true
  # EKS Auto Mode only
  cluster_compute_config = {
    enabled    = true
    node_pools = ["general-purpose"]
  }
  vpc_id     = module.vpc.inner.vpc_id
  subnet_ids = module.vpc.inner.private_subnets
  tags = {
    Environment = var.environment_name
    Terraform   = "true"
  }
}

# Install EKS addons including NGINX Ingress Controller
module "eks_blueprints_addons" {
  source  = "aws-ia/eks-blueprints-addons/aws"
  version = "~> 1.0"

  cluster_name      = module.retail_app_eks.cluster_name
  cluster_endpoint  = module.retail_app_eks.cluster_endpoint
  cluster_version   = module.retail_app_eks.cluster_version
  oidc_provider_arn = module.retail_app_eks.oidc_provider_arn

  # Enable cert-manager for SSL certificates
  enable_cert_manager = true
  
  # Enable NGINX Ingress Controller
  enable_ingress_nginx = true
  ingress_nginx = {
    most_recent = true
    namespace   = "ingress-nginx"
    set = [
      {
        name  = "controller.service.type"
        value = "LoadBalancer"
      },
      {
        name  = "controller.service.externalTrafficPolicy"
        value = "Local"
      },
      {
        name  = "controller.resources.requests.cpu"
        value = "100m"
      },
      {
        name  = "controller.resources.requests.memory"
        value = "128Mi"
      },
      {
        name  = "controller.resources.limits.cpu"
        value = "200m"
      },
      {
        name  = "controller.resources.limits.memory"
        value = "256Mi"
      }
    ]
    set_sensitive = [
      {
        name  = "controller.service.annotations.service\\.beta\\.kubernetes\\.io/aws-load-balancer-scheme"
        value = "internet-facing"
      },
      {
        name  = "controller.service.annotations.service\\.beta\\.kubernetes\\.io/aws-load-balancer-type"
        value = "nlb"
      },
      {
        name  = "controller.service.annotations.service\\.beta\\.kubernetes\\.io/aws-load-balancer-nlb-target-type"
        value = "instance"
      },
      {
        name  = "controller.service.annotations.service\\.beta\\.kubernetes\\.io/aws-load-balancer-health-check-path"
        value = "/healthz"
      },
      {
        name  = "controller.service.annotations.service\\.beta\\.kubernetes\\.io/aws-load-balancer-health-check-port"
        value = "10254"
      },
      {
        name  = "controller.service.annotations.service\\.beta\\.kubernetes\\.io/aws-load-balancer-health-check-protocol"
        value = "HTTP"
      },
      {
        name  = "controller.service.annotations.service\\.beta\\.kubernetes\\.io/aws-load-balancer-health-check-healthy-threshold"
        value = "2"
      },
      {
        name  = "controller.service.annotations.service\\.beta\\.kubernetes\\.io/aws-load-balancer-health-check-unhealthy-threshold"
        value = "2"
      },
      {
        name  = "controller.service.annotations.service\\.beta\\.kubernetes\\.io/aws-load-balancer-health-check-timeout"
        value = "5"
      },
      {
        name  = "controller.service.annotations.service\\.beta\\.kubernetes\\.io/aws-load-balancer-health-check-interval"
        value = "30"
      }
    ]
  }

  depends_on = [module.retail_app_eks]
}



# Allow internet traffic to LoadBalancer
resource "aws_security_group_rule" "internet_to_lb" {
  description       = "Allow internet traffic to LoadBalancer"
  type              = "ingress"
  from_port         = 80
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = module.retail_app_eks.cluster_security_group_id
}

# Allow LoadBalancer health checks from AWS
resource "aws_security_group_rule" "aws_health_checks_to_lb" {
  description       = "Allow AWS health checks to LoadBalancer"
  type              = "ingress"
  from_port         = 10254
  to_port           = 10254
  protocol          = "tcp"
  cidr_blocks       = [module.vpc.inner.vpc_cidr_block] 
  security_group_id = module.retail_app_eks.cluster_security_group_id
}
