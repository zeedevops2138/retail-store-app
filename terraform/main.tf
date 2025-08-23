# ============ VPC AND EKS MODULES CONFIGURATION ==============


# =============== VPC MODULE ===============
# ==========================================

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = var.vpc_name
  cidr = var.vpc_cidr

  azs             = var.azs
  public_subnets  = var.public_subnets
  private_subnets = var.private_subnets

  enable_nat_gateway = true
  single_nat_gateway = true

  tags = var.tags
}

# ================ EKS MODULE ===============
# ==========================================

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 21.0"

  name               = var.eks_cluster_name
  kubernetes_version = var.eks_kubernetes_version
  

  # Optional
  endpoint_public_access = true

  # Optional: Adds the current caller identity as an administrator via cluster access entry
  enable_cluster_creator_admin_permissions = true

  vpc_id                   = module.vpc.vpc_id
  subnet_ids               = module.vpc.private_subnets
  control_plane_subnet_ids = module.vpc.private_subnets
  additional_security_group_ids = [aws_security_group.eks_cluster_sg.id]

  # EKS Managed Node Group(s)
  eks_managed_node_groups = {
    example = {

      ami_type       = var.ami_type
      instance_types = var.instance_types
      min_size     = 2
      max_size     = 4
      desired_size = 2

    }
  }

  tags = var.tags

}

# ================ HELM RELEASE FOR ARGOCD ===============
# ========================================================

resource "time_sleep" "wait_for_cluster" {
  create_duration = "30s"
  depends_on = [
    module.eks,
    module.eks.addons
  ]
}

resource "helm_release" "argocd" {
  name             = "argocd"
  namespace        = "argocd"
  create_namespace = true

  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  version    = "5.51.6"

  values = [
    yamlencode({
      server = {
        service = {
          type = "ClusterIP"  # Port-forwarding access only
        }
        ingress = {
          enabled = false
        }
        extraArgs = ["--insecure"]
      }

      controller = {
        resources = {
          requests = {
            cpu    = "100m"
            memory = "128Mi"
          }
          limits = {
            cpu    = "500m"
            memory = "512Mi"
          }
        }
      }

      repoServer = {
        resources = {
          requests = {
            cpu    = "50m"
            memory = "64Mi"
          }
          limits = {
            cpu    = "200m"
            memory = "256Mi"
          }
        }
      }

      redis = {
        resources = {
          requests = {
            cpu    = "50m"
            memory = "64Mi"
          }
          limits = {
            cpu    = "200m"
            memory = "128Mi"
          }
        }
      }
    })
  ]

  depends_on = [time_sleep.wait_for_cluster]
}

resource "time_sleep" "wait_for_argocd" {
  create_duration = "60s"
  depends_on      = [helm_release.argocd]
}


