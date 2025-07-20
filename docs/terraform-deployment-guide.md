# Terraform EKS Deployment Guide & Troubleshooting

## 🐛 **Error Analysis**

### **The Problem**
The original Terraform configuration had a classic "chicken-and-egg" problem:

```bash
Error: reading EKS Cluster (retail-store): couldn't find resource

  with data.aws_eks_cluster.this,
  on versions.tf line 39, in data "aws_eks_cluster" "this":
```

### **Root Cause**
The issue occurred because:

1. **Data sources** tried to read EKS cluster information **before** the cluster existed
2. **Kubernetes/Helm providers** were configured using these data sources during provider initialization
3. **Terraform** attempts to configure all providers before creating any resources
4. **Result**: Data source fails → Provider configuration fails → Deployment fails

### **Original Problematic Code**
```hcl
# ❌ BROKEN: Data source tries to read non-existent cluster
data "aws_eks_cluster" "this" {
  name = module.retail_app_eks.cluster_name
}

# ❌ BROKEN: Provider uses data source that fails
provider "kubernetes" {
  host                   = data.aws_eks_cluster.this.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.this.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.this.token
}
```

## ✅ **Solution Implemented**

### **1. Fixed Provider Configuration**
Changed from cluster API-based authentication to kubeconfig-based authentication:

```hcl
# ✅ FIXED: Uses kubeconfig instead of data sources
provider "kubernetes" {
  config_path    = "~/.kube/config"
  config_context = module.retail_app_eks.cluster_name
}

provider "helm" {
  # Uses default kubeconfig - no cluster dependency
}
```

### **2. Made Data Sources Conditional**
```hcl
# ✅ FIXED: Conditional data sources
data "aws_eks_cluster" "this" {
  count = length(module.retail_app_eks.cluster_name) > 0 ? 1 : 0
  name  = module.retail_app_eks.cluster_name
}
```

### **3. Updated Deployment Process**
The fix requires a **two-stage deployment**:

1. **Stage 1**: Create infrastructure (VPC, EKS cluster, bastion)
2. **Configure kubectl**: Set up kubeconfig for cluster access  
3. **Stage 2**: Deploy ArgoCD and applications

## 🚀 **Correct Deployment Workflow**

### **Step 1: Infrastructure Deployment**
```bash
cd terraform/eks/default

# Initialize Terraform
terraform init

# Deploy base infrastructure
terraform apply
```

**What gets created:**
- ✅ VPC with public/private subnets
- ✅ EKS cluster with Auto Mode
- ✅ Bastion host with SSH keys
- ✅ Security groups and networking

### **Step 2: Configure kubectl (CRITICAL)**
```bash
# Get the command from Terraform output
terraform output -raw configure_kubectl

# Example: aws eks --region eu-west-1 update-kubeconfig --name retail-store
aws eks --region eu-west-1 update-kubeconfig --name retail-store

# Verify connection
kubectl cluster-info
kubectl get nodes
```

**Why this step is critical:**
- 🔑 Kubernetes/Helm providers need kubeconfig access
- 📝 ArgoCD installation requires kubectl connectivity
- 🎯 Second terraform apply depends on working kubectl

### **Step 3: Complete Deployment**
```bash
# This will now work because kubectl is configured
terraform apply
```

**What gets deployed:**
- ✅ NGINX Ingress Controller
- ✅ ArgoCD for GitOps
- ✅ ArgoCD projects and applications
- ✅ Cert-manager for SSL

## 🔧 **Technical Details**

### **Provider Authentication Methods**

| Method | Use Case | Pros | Cons |
|--------|----------|------|------|
| **Data Source** | Post-deployment | Direct API access | Chicken-egg problem |
| **Kubeconfig** | Initial deployment | No dependencies | Requires kubectl setup |
| **Exec Plugin** | Advanced setups | Dynamic auth | Complex configuration |

### **Why Kubeconfig is Better for This Use Case**

1. **No Dependencies**: Doesn't depend on Terraform resources
2. **Standard Practice**: Uses same auth method as kubectl
3. **Reliable**: Works consistently across environments
4. **Flexible**: Can be updated independently

### **EKS Auto Mode Benefits**

The deployment uses EKS Auto Mode which provides:
- **Automatic node provisioning** based on workload demands
- **Simplified management** - no node groups to configure
- **Cost optimization** through automatic scaling
- **Reduced operational overhead**

## 🔍 **Troubleshooting Guide**

### **Common Issues and Solutions**

#### **1. Data Source Error**
```bash
Error: reading EKS Cluster (retail-store): couldn't find resource
```
**Solution**: Follow the two-stage deployment process above.

#### **2. kubectl Not Configured**
```bash
Error: Unauthorized (401)
```
**Solution**: 
```bash
aws eks --region <region> update-kubeconfig --name retail-store
kubectl cluster-info
```

#### **3. Provider Configuration Issues**
```bash
Error: Invalid provider configuration
```
**Solution**:
```bash
export KUBECONFIG=~/.kube/config
kubectl config current-context
```

#### **4. ArgoCD Installation Fails**
```bash
Error: failed to install ArgoCD
```
**Solution**:
```bash
# Verify kubectl works
kubectl get nodes
# Then retry terraform apply
terraform apply
```

### **Validation Commands**

```bash
# Check Terraform configuration
terraform validate

# Check EKS cluster
kubectl cluster-info
kubectl get nodes

# Check ArgoCD
kubectl get pods -n argocd
kubectl get applications -n argocd

# Check NGINX Ingress
kubectl get svc -n ingress-nginx
```

## 🎯 **Best Practices**

### **1. Always Follow Deployment Order**
1. Terraform apply (infrastructure)
2. Configure kubectl
3. Terraform apply (applications)

### **2. Verify Each Step**
```bash
# After infrastructure
terraform output configure_kubectl

# After kubectl config
kubectl cluster-info

# After complete deployment
kubectl get applications -n argocd
```

### **3. Use Consistent Regions**
Ensure AWS CLI, kubectl, and Terraform use the same region:
```bash
aws configure get region
kubectl config current-context
```

### **4. Monitor Resource Creation**
```bash
# Watch cluster creation (takes 15-20 minutes)
watch kubectl get nodes

# Monitor ArgoCD deployment
watch kubectl get pods -n argocd
```

## 📚 **Integration with GitOps Workflow**

Once the infrastructure is deployed correctly:

1. **GitHub Actions** build and push images to ECR
2. **Helm values** are automatically updated with new image tags
3. **ArgoCD** detects changes and syncs applications
4. **Applications** are deployed with the latest images

This creates a complete CI/CD pipeline from code push to production deployment.

## 🧹 **Cleanup**

To destroy all resources:
```bash
# Destroy all Terraform resources
terraform destroy

# Verify cleanup
aws eks list-clusters --region <region>
```

## 📞 **Support**

If you encounter issues:
1. Check the troubleshooting section above
2. Verify deployment steps were followed in order
3. Ensure kubectl is properly configured
4. Check AWS permissions and region consistency 