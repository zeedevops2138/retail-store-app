# Retail Store Sample App - GitOps with EKS Auto Mode

![Banner](./docs/images/banner.png)

<div align="center">
  <div align="center">

[![Stars](https://img.shields.io/github/stars/aws-containers/retail-store-sample-app)](Stars)
![GitHub License](https://img.shields.io/github/license/aws-containers/retail-store-sample-app?color=green)
![Dynamic JSON Badge](https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Faws-containers%2Fretail-store-sample-app%2Frefs%2Fheads%2Fmain%2F.release-please-manifest.json&query=%24%5B%22.%22%5D&label=release)
![GitHub Release Date](https://img.shields.io/github/release-date/aws-containers/retail-store-sample-app)

  </div>

  <strong>
  <h2>AWS Containers Retail Sample</h2>
  </strong>
</div>

This is a sample application designed to illustrate various concepts related to containers on AWS. It presents a sample retail store application including a product catalog, shopping cart and checkout, deployed using modern DevOps practices including GitOps and Infrastructure as Code.

## Table of Contents

- [Overview](#overview)
- [Architecture](#architecture)
- [Prerequisites](#prerequisites)
- [Getting Started](#getting-started)
- [GitOps Workflow](#gitops-workflow)
- [EKS Auto Mode](#eks-auto-mode)
- [Infrastructure Components](#infrastructure-components)
- [CI/CD Pipeline](#cicd-pipeline)
- [Monitoring and Observability](#monitoring-and-observability)
- [Cleanup](#cleanup)
- [Troubleshooting](#troubleshooting)

## Overview

The Retail Store Sample App demonstrates a modern microservices architecture deployed on AWS EKS using GitOps principles. The application consists of multiple services that work together to provide a complete retail store experience:

- **UI Service**: Java-based frontend
- **Catalog Service**: Go-based product catalog API
- **Cart Service**: Java-based shopping cart API
- **Orders Service**: Java-based order management API
- **Checkout Service**: Node.js-based checkout orchestration API

All components are instrumented for Prometheus metrics and OpenTelemetry OTLP tracing, making this an excellent example for learning about cloud-native observability.

## Application Architecture

![Architecture Diagram](./docs/images/architecture.png)

The application architecture follows cloud-native best practices:

- **Microservices**: Each component is developed and deployed independently
- **Containerization**: All services run as containers on Kubernetes
- **GitOps**: Infrastructure and application deployment managed through Git
- **Infrastructure as Code**: All AWS resources defined using Terraform
- **CI/CD**: Automated build and deployment pipelines with GitHub Actions

## Prerequisites

Before you begin, ensure you have the following tools installed:

- **AWS CLI** (configured with appropriate credentials)
- **Terraform** (version 1.0.0 or later)
- **kubectl** (compatible with Kubernetes 1.23+)
- **Git** (2.0.0 or later)
- **Docker** (for local development)


## Getting Started

Follow these steps to deploy the application:

### step 1. Clone the Repository

```bash
git clone https://github.com/iemafzalhassan/retail-store-sample-app.git
cd retail-store-sample-app
```


### step 2. Configure AWS Credentials

Ensure your AWS CLI is configured with the appropriate credentials:

```bash
aws configure
```

### step 3. Deploy Infrastructure with Terraform

The deployment is split into two phases for better control:


### Phase 1 of Terraform: Create EKS Cluster 

In 1st Phase: Terraform Initializes and Creates resources inside retail_app_eks module. 

```bash
terraform init
terraform apply -target=module.retail_app_eks
```

<img width="1205" height="292" alt="image" src="https://github.com/user-attachments/assets/6f1e407e-4a4e-4a4c-9bdf-0c9b89681368" />


This creates the core infrastructure including:
- VPC with public and private subnets
- Amazon EKS cluster with Auto Mode enabled
- Bastion host for secure cluster access
- Security groups and IAM roles

  

### Step 4: Update kubeconfig to Access the Amazon EKS Cluster
```
aws eks update-kubeconfig --name retail-store --region ap-south-1
```

### Phase 2 of Terraform: Once you update kubeconfig apply Remaining Configuration 


```bash
terraform apply --auto-approve
```

This deploys:
- ArgoCD for Setup GitOps
- NGINX Ingress Controller
- Cert Manager for SSL certificates

### Step 5: GitHub Actions

For GitHub Actions first configure secrets so the pipelines can be automatically triggred:

**Create an IAM User, policies, and Generate Credentails**

**Go to your GitHub repo → Settings → Secrets and variables → Actions → New repository secret.**


| Secret Name           | Value                              |
|-----------------------|------------------------------------|
| `AWS_ACCESS_KEY_ID`   | `Your AWS Access Key ID`           |
| `AWS_SECRET_ACCESS_KEY` | `Your AWS Secret Access Key`     |
| `AWS_REGION`          | `region-name`                       |
| `AWS_ACCOUNT_ID`        | `your-account-id` |



> [!IMPORTANT]
> Once the entire cluster is created, any changes pushed to the repository will automatically trigger GitHub Actions.

GitHub Actions will automatically build and push the updated Docker images to Amazon ECR.



<img width="2868" height="1130" alt="image" src="https://github.com/user-attachments/assets/f29c3416-d630-4463-81d2-aaa8af9a02da" />



### 5. Verify Deployment

Check if the nodes are running:

```bash
kubectl get nodes
```

<img width="965" height="74" alt="image" src="https://github.com/user-attachments/assets/b1dfbf44-ea7d-44c2-afa1-b7a1be8a5fe3" />


Check the status of the pods:

```bash
kubectl get pods -A
```

### 6. Access the Application

The application is exposed through the NGINX Ingress Controller. Get the load balancer URL:

```bash
kubectl get svc -n ingress-nginx
```

Use the EXTERNAL-IP of the ingress-nginx-controller service to access the application.

## GitOps Workflow

This project implements GitOps principles, where Git is the `single source of truth` for both infrastructure and application deployments.

### What is GitOps?

GitOps is a set of practices that uses Git as the `single source of truth` for declarative infrastructure and applications. With GitOps:

1. All system changes are made through Git
2. Changes are automatically applied to the system
3. The system continuously reconciles to match the desired state in Git

### How GitOps Works in This Project

1. **Infrastructure as Code (Terraform)**:
   - VPC, EKS, and all AWS resources are defined in Terraform
   - Changes to infrastructure require changes to Terraform files
   - Changes are applied through the Terraform workflow

2. **Application Deployment (ArgoCD)**:
   - ArgoCD monitors the Git repository for changes
   - When changes are detected, ArgoCD automatically applies them to the cluster
   - The system continuously reconciles to match the desired state

3. **CI/CD Pipeline (GitHub Actions)**:
   - Code changes trigger automated builds
   - New container images are pushed to ECR
   - Helm chart values are updated with new image tags
   - ArgoCD detects the changes and deploys the new versions

## EKS Auto Mode

This project uses EKS Auto Mode, a simplified way to manage EKS clusters.

### What is EKS Auto Mode?

EKS Auto Mode is a feature that simplifies node management by automatically:

1. Creating and managing node groups based on workload requirements
2. Scaling nodes up and down based on demand
3. Handling node updates and replacements

### Benefits of EKS Auto Mode

- **Simplified Management**: No need to manually configure node groups
- **Cost Optimization**: Automatically scales based on actual usage
- **Improved Reliability**: Automatic node replacement for failed nodes
- **Seamless Updates**: Simplified Kubernetes version upgrades

## Infrastructure Components

The infrastructure is built using Terraform and consists of:

### VPC Configuration

- **CIDR Block**: 10.0.0.0/16
- **Availability Zones**: 3 AZs for high availability
- **Public Subnets**: For bastion host and load balancers
- **Private Subnets**: For EKS nodes (secure by design)
- **NAT Gateway**: For outbound internet access from private subnets
- **Internet Gateway**: For inbound/outbound access from public subnets

### EKS Cluster

- **Version**: Kubernetes 1.33
- **Auto Mode**: Enabled with general-purpose node pools
- **Endpoint Access**: Public endpoint with security group restrictions
- **Add-ons**:
  - NGINX Ingress Controller
  - Cert Manager for SSL certificates

### Security

- **Bastion Host**: Ubuntu EC2 instance in public subnet for secure cluster access
- **Security Groups**: Properly configured for least privilege access
- **IAM Roles**: Following AWS best practices for permissions

## CI/CD Pipeline

The CI/CD pipeline is implemented using GitHub Actions and consists of:

### 1. Semantic Release

- Automatically determines the next version number
- Creates Git tags and releases
- Updates the changelog

### 2. Container Build and Push

- Builds Docker images for all microservices
- Scans images for security vulnerabilities using Trivy
- Tags images with branch-commit format
- Pushes images to Amazon ECR

### 3. Helm Chart Updates

- Updates Helm chart values.yaml with new image tags
- Commits changes back to the repository
- Triggers ArgoCD synchronization

### 4. GitOps Deployment

- ArgoCD detects changes in the Git repository
- Automatically applies changes to the Kubernetes cluster
- Ensures the cluster state matches the desired state in Git

## Monitoring and Observability

The application includes built-in monitoring and observability:

- **Prometheus Metrics**: All services expose Prometheus metrics
- **OpenTelemetry Tracing**: Distributed tracing across services
- **Health Checks**: Readiness and liveness probes for all services

## Cleanup

To delete all resources created by Terraform:

```bash
terraform destroy -target=module.retail_app_eks --auto-approve
terraform destroy --auto-approve
```

This will remove all AWS resources created for this project.

## Troubleshooting

### Common Issues

1. **EKS Cluster Creation Fails**:
   - Check IAM permissions
   - Ensure you have sufficient quotas in your AWS account

2. **ArgoCD Sync Fails**:
   - Check ArgoCD logs: `kubectl logs -n argocd deployment/argocd-application-controller`
   - Verify the Git repository is accessible

3. **Services Not Accessible**:
   - Check ingress controller: `kubectl get svc -n ingress-nginx`
   - Verify security group rules allow traffic

### Getting Help

If you encounter issues, please:
1. Check the existing GitHub issues
2. Create a new issue with detailed information about your problem

## Contributing

Contributions are welcome! Please see [CONTRIBUTING.md](./CONTRIBUTING.md) for details.

## License

This project is licensed under the Apache License 2.0 - see the [LICENSE](./LICENSE) file for details.
