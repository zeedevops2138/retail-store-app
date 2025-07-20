# AWS Containers Retail Sample - EKS Terraform (Default)

This Terraform module creates all the necessary infrastructure and deploys the retail sample application on [Amazon Elastic Kubernetes Service](https://aws.amazon.com/eks/) (EKS) with **EKS Auto Mode** enabled. This configuration will deploy all application dependencies using AWS managed services such as Amazon RDS and Amazon DynamoDB.

## 🚀 What This Deploys

- **VPC** with public and private subnets
- **EKS cluster** with EKS Auto Mode enabled for simplified node management
- **Bastion host** for secure cluster access
- **NGINX Ingress Controller** for application routing
- **ArgoCD** for GitOps-based application deployment
- **Cert-Manager** for SSL certificate management
- Automatic compute provisioning with general-purpose node pools
- All application dependencies such as RDS, DynamoDB table, Elasticache etc.

## 🔄 GitOps Workflow

This project implements a complete GitOps workflow:

```
Code Push → GitHub Actions → Build Images → Push to ECR → Update Helm Values → ArgoCD Sync → Deploy Apps
```

1. **Code Push**: Developer pushes code to main branch
2. **GitHub Actions**: Automatically builds Docker images
3. **Push to ECR**: Images pushed to AWS private ECR repositories
4. **Update Helm Values**: Automated update of Helm chart values with new image tags
5. **ArgoCD Sync**: ArgoCD detects changes and automatically syncs
6. **Deploy Apps**: Applications deployed with latest images to EKS

## 📋 Prerequisites

- AWS CLI installed and configured with appropriate permissions
- Terraform >= 1.0.0 installed locally
- kubectl installed locally
- AWS account with sufficient permissions

### Required AWS Permissions

Your AWS user/role needs permissions for:
- EKS cluster management
- VPC and networking resources
- IAM roles and policies
- EC2 instances (for bastion host)
- ECR repositories
- Application Load Balancers

## 🛠️ Deployment Instructions

### Step 1: Initialize Terraform

```bash
# Clone the repository
git clone <your-repo-url>
cd terraform/eks/default

# Initialize Terraform
terraform init
```

### Step 2: Initial Infrastructure Deployment

```bash
# Plan the deployment
terraform plan

# Apply the infrastructure (this takes 15-20 minutes)
# Note: This will create VPC, EKS cluster, and bastion host
terraform apply
```

### Step 3: Configure kubectl (CRITICAL STEP)

**IMPORTANT**: You must configure kubectl immediately after EKS cluster creation:

```bash
# Get the kubectl configuration command from Terraform output
terraform output -raw configure_kubectl

# Example output: aws eks --region eu-west-1 update-kubeconfig --name retail-store
# Run the command shown in the output
aws eks --region <your-region> update-kubeconfig --name retail-store

# Verify connection works
kubectl cluster-info
kubectl get nodes
```

### Step 4: Complete Deployment (ArgoCD and Applications)

After configuring kubectl, apply Terraform again to install ArgoCD and deploy applications:

```bash
# This will now work because kubectl is configured
terraform apply
```

This second apply will:
- Install NGINX Ingress Controller
- Install ArgoCD using Helm
- Apply ArgoCD project and application manifests
- Set up GitOps for automatic deployments

## 🔍 Verification Steps

### 1. Check Infrastructure

```bash
# Check EKS cluster
kubectl get nodes

# Check NGINX Ingress Controller
kubectl get pods -n ingress-nginx
kubectl get svc -n ingress-nginx

# Get NGINX LoadBalancer endpoint
kubectl get svc -n ingress-nginx ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
```

### 2. Check ArgoCD

```bash
# Check ArgoCD pods
kubectl get pods -n argocd

# Get ArgoCD admin password
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d

# Port forward to ArgoCD UI
kubectl port-forward -n argocd svc/argocd-server 8080:443

# Access ArgoCD at https://localhost:8080
# Username: admin
# Password: (from previous command)
```

### 3. Check Application Deployment

```bash
# Check ArgoCD applications
kubectl get applications -n argocd

# Check retail store pods
kubectl get pods -n retail-store

# Check ingress
kubectl get ingress -n retail-store
```

## 🌐 Access the Application

### Via NGINX Ingress Controller

```bash
# Get the LoadBalancer hostname
NGINX_ENDPOINT=$(kubectl get svc -n ingress-nginx ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

# Access the application
curl http://$NGINX_ENDPOINT
# Or open in browser: http://<nginx-endpoint>
```

### Via Port Forward (for testing)

```bash
kubectl port-forward -n retail-store svc/ui 8080:80
# Access at http://localhost:8080
```

## 📊 Monitoring and Troubleshooting

### Common Terraform Deployment Issues

#### 1. EKS Cluster Data Source Error
If you see: `Error: reading EKS Cluster (retail-store): couldn't find resource`

**Solution**: This is resolved in the current configuration, but ensure you follow the deployment steps in order:
```bash
# 1. Apply infrastructure first
terraform apply
# 2. Configure kubectl immediately after cluster creation
aws eks --region <region> update-kubeconfig --name retail-store
# 3. Apply again to complete ArgoCD installation
terraform apply
```

#### 2. kubectl Configuration Issues
If ArgoCD installation fails with connection errors:

```bash
# Verify kubectl is configured correctly
kubectl cluster-info
kubectl get nodes

# If not working, reconfigure
aws eks --region <region> update-kubeconfig --name retail-store
```

#### 3. Provider Configuration Issues
If you see Kubernetes/Helm provider errors:

```bash
# Ensure your kubeconfig is properly set
export KUBECONFIG=~/.kube/config
kubectl config current-context
```

### Check ArgoCD Application Status

```bash
# List all applications
kubectl get applications -n argocd

# Get detailed status
kubectl describe application retail-store-ui -n argocd
```

### Debug Pod Issues

```bash
# Check pod status
kubectl get pods -n retail-store

# Get pod logs
kubectl logs <pod-name> -n retail-store

# Describe pod for events
kubectl describe pod <pod-name> -n retail-store
```

### ArgoCD Sync Issues

```bash
# Manual sync application
kubectl patch application retail-store-ui -n argocd --type='merge' -p='{"spec":{"syncPolicy":{"automated":{"prune":true,"selfHeal":true}}}}'

# Check sync status
kubectl get application retail-store-ui -n argocd -o yaml
```

### NGINX Ingress Controller Issues

```bash
# Check NGINX Ingress Controller status
kubectl get pods -n ingress-nginx
kubectl get svc -n ingress-nginx

# Get LoadBalancer endpoint (may take a few minutes)
kubectl get svc -n ingress-nginx ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
```

## 🔧 Configuration Details

### EKS Auto Mode Benefits

This configuration uses EKS Auto Mode, which provides:
- **Simplified node management**: No need to configure managed node groups manually
- **Automatic scaling**: Nodes are provisioned and scaled automatically based on workload demands
- **Cost optimization**: Automatic rightsizing and efficient resource utilization
- **Reduced operational overhead**: AWS manages the underlying compute infrastructure

### NGINX Ingress Controller Configuration

The NGINX Ingress Controller is configured with:
- LoadBalancer service type for external access
- Resource limits for optimal performance
- Local external traffic policy for better performance
- SSL termination capabilities

### ArgoCD Configuration

ArgoCD is configured to:
- Monitor the GitHub repository for changes
- Automatically sync applications when changes are detected
- Use Helm charts for application deployment
- Implement sync waves for proper deployment ordering

## 💰 Cost Considerations

NOTE: This will create resources in your AWS account which will incur costs. You are responsible for these costs, and should understand the resources being created before proceeding.

Main cost components:
- EKS cluster: ~$72/month for control plane
- EC2 instances: Variable based on Auto Mode scaling
- Load Balancers: ~$16-25/month per ALB
- Data transfer costs
- Storage costs for EBS volumes

## 🧹 Cleanup

To destroy all resources:

```bash
# Destroy Terraform resources
terraform destroy

# Clean up any remaining resources
kubectl delete namespace retail-store --ignore-not-found=true
kubectl delete namespace argocd --ignore-not-found=true
```

## 📚 Reference

### Environment Variables

| Name                    | Description                                                                                                                                                                                        | Type     | Default        | Required |
| ----------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------- | -------------- | :------: |
| `environment_name`      | Name of the environment which will be used for all resources created                                                                                                                               | `string` | `retail-store` |   yes    |
| `argocd_namespace`      | Namespace to install Argo CD                                                                                                                                                                      | `string` | `argocd`       |    no    |
| `argocd_chart_version`  | Argo CD Helm chart version                                                                                                                                                                         | `string` | `5.51.6`       |    no    |

### Outputs

| Name                | Description                                            |
| ------------------- | ------------------------------------------------------ |
| `configure_kubectl` | AWS CLI command to configure `kubectl` for EKS cluster |
| `argocd_credentials` | ArgoCD access credentials and commands |
| `nginx_ingress_endpoint` | NGINX Ingress Controller LoadBalancer endpoint |
| `deployment_instructions` | Complete step-by-step deployment instructions |

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.
