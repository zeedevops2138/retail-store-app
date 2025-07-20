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
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.4"
    }
    time = {
      source  = "hashicorp/time"
      version = "~> 0.12"
    }
  }
}

provider "aws" {}

# EKS cluster connection for Kubernetes/Helm providers
# These data sources are conditional to avoid chicken-and-egg problem during initial deployment
data "aws_eks_cluster" "this" {
  count = length(module.retail_app_eks.cluster_name) > 0 ? 1 : 0
  name  = module.retail_app_eks.cluster_name
}

data "aws_eks_cluster_auth" "this" {
  count = length(module.retail_app_eks.cluster_name) > 0 ? 1 : 0
  name  = module.retail_app_eks.cluster_name
}

# Kubernetes provider configuration
# Uses kubeconfig-based authentication to avoid dependency issues
provider "kubernetes" {
  # Use kubeconfig for authentication - more reliable for initial deployment
  config_path    = "~/.kube/config"
  config_context = module.retail_app_eks.cluster_name
}

# Helm provider configuration  
# Uses kubeconfig for authentication to avoid dependency issues
provider "helm" {
  # Use default kubeconfig for authentication - more reliable for initial deployment
}
