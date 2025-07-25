terraform {
  required_version = ">= 1.0.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.79"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.2"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.17.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.37.0"
    }

    time = {
      source  = "hashicorp/time"
      version = "~> 0.12"
    }
  }
}

provider "aws" {}

# EKS cluster connection for Kubernetes/Helm providers
data "aws_eks_cluster" "this" {
  count = length(module.retail_app_eks.cluster_name) > 0 ? 1 : 0
  name  = module.retail_app_eks.cluster_name
}

data "aws_eks_cluster_auth" "this" {
  count = length(module.retail_app_eks.cluster_name) > 0 ? 1 : 0
  name  = module.retail_app_eks.cluster_name
}

# Kubernetes provider configuration
provider "kubernetes" {
  host                   = module.retail_app_eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.retail_app_eks.cluster_certificate_authority_data)
  token                  = data.aws_eks_cluster_auth.this[0].token
}

# Helm provider configuration  
provider "helm" {
  kubernetes {
    host                   = module.retail_app_eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.retail_app_eks.cluster_certificate_authority_data)
    token                  = data.aws_eks_cluster_auth.this[0].token
  }
}
