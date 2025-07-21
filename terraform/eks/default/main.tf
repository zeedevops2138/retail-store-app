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

# --- Bastion SSH Key Generation ---
resource "tls_private_key" "bastion" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

# Save private key to file with secure permissions
resource "local_file" "bastion_private_key" {
  content         = tls_private_key.bastion.private_key_pem
  filename        = "${path.module}/keys/bastion_key.pem"
  file_permission = "0400"
}

# Save public key to file in OpenSSH format
resource "local_file" "bastion_public_key" {
  content         = tls_private_key.bastion.public_key_openssh
  filename        = "${path.module}/keys/bastion_key.pub"
  file_permission = "0644"
}

# Create AWS Key Pair with OpenSSH format
resource "aws_key_pair" "bastion" {
  key_name   = "${var.environment_name}-bastion-key"
  public_key = tls_private_key.bastion.public_key_openssh
}


# --- Bastion Security Group ---
resource "aws_security_group" "bastion" {
  name        = "${var.environment_name}-bastion-sg"
  description = "Allow SSH access to bastion"
  vpc_id      = module.vpc.inner.vpc_id
  ingress {
    description = "SSH from anywhere (change for production!)"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = module.tags.result
}

# --- Ubuntu AMI Data Source ---
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
}

# --- Bastion User Data ---
locals {
  bastion_user_data = <<-EOF
    #!/bin/bash
    set -e
    apt-get update -y

    apt-get install -y curl unzip apt-transport-https ca-certificates gnupg lsb-release
    
    # Install AWS CLI v2
    curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "/tmp/awscliv2.zip"
    unzip -q /tmp/awscliv2.zip -d /tmp
    /tmp/aws/install
    
    # Install kubectl (latest stable)
    curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
    install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
    rm kubectl
    
    # Install eksctl (latest)
    curl --silent --location "https://github.com/weaveworks/eksctl/releases/latest/download/eksctl_$(uname -s)_amd64.tar.gz" | tar xz -C /tmp
    mv /tmp/eksctl /usr/local/bin

    # Install Helm
    curl https://baltocdn.com/helm/signing.asc | gpg --dearmor | tee /usr/share/keyrings/helm.gpg > /dev/null
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/helm.gpg] https://baltocdn.com/helm/stable/debian/ all main" | tee /etc/apt/sources.list.d/helm-stable-debian.list
    apt-get update -y
    apt-get install -y helm

    
    # Clean up
    rm -rf /tmp/awscliv2.zip /tmp/aws /tmp/eksctl
    apt-get autoremove -y
    apt-get autoclean -y
    
    # Print versions for verification
    aws --version
    kubectl version --client
    eksctl version
    helm version
  EOF
}

# --- Bastion EC2 Instance (Ubuntu) ---
resource "aws_instance" "bastion" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = "t3.micro"
  subnet_id                   = module.vpc.inner.public_subnets[0]
  vpc_security_group_ids      = [aws_security_group.bastion.id]
  key_name                    = aws_key_pair.bastion.key_name
  user_data                   = local.bastion_user_data
  associate_public_ip_address = true
  tags = {
    Name = "${var.environment_name}-bastion"
  }
}

# --- Security Group Rules for Bastion to EKS Access ---

# Allow bastion access to EKS cluster API
resource "aws_security_group_rule" "bastion_to_eks_cluster" {
  description              = "Allow bastion to access EKS cluster API"
  type                     = "ingress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.bastion.id
  security_group_id        = module.retail_app_eks.cluster_security_group_id
}

# Allow bastion access to EKS nodes (for debugging and kubectl proxy)
resource "aws_security_group_rule" "bastion_to_eks_nodes" {
  description              = "Allow bastion to access EKS nodes"
  type                     = "ingress"
  from_port                = 10250
  to_port                  = 10250
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.bastion.id
  security_group_id        = module.retail_app_eks.node_security_group_id
}

# Allow bastion access to EKS node kubelet health checks
resource "aws_security_group_rule" "bastion_to_eks_nodes_health" {
  description              = "Allow bastion to access EKS node health checks"
  type                     = "ingress"
  from_port                = 1025
  to_port                  = 1025
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.bastion.id
  security_group_id        = module.retail_app_eks.node_security_group_id
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
