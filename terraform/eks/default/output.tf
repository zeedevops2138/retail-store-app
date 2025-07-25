data "aws_region" "current" {}

output "configure_kubectl" {
  description = "Command to update kubeconfig for this cluster"
  value       = "aws eks --region ${data.aws_region.current.name} update-kubeconfig --name ${module.retail_app_eks.cluster_name}"
}


output "deployment_instructions" {
  description = "Step-by-step deployment instructions for the GitOps workflow"
  value = <<-EOT
    # ========================================
    # GITOPS DEPLOYMENT WORKFLOW INSTRUCTIONS
    # ========================================
    
    # STEP 1: Configure kubectl (REQUIRED BEFORE terraform apply)
    aws eks --region ${data.aws_region.current.name} update-kubeconfig --name ${module.retail_app_eks.cluster_name}
    
    # STEP 2: Verify kubectl connection
    kubectl cluster-info
    kubectl get nodes
    
    # STEP 3: Verify NGINX Ingress Controller installation
    kubectl get pods -n ingress-nginx
    kubectl get svc -n ingress-nginx
    
    # STEP 4: Get NGINX Load Balancer external IP/hostname
    kubectl get svc -n ingress-nginx ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
    
    # STEP 5: Verify ArgoCD installation
    kubectl get pods -n ${var.argocd_namespace}
    kubectl get svc -n ${var.argocd_namespace}
    
    # STEP 6: Get ArgoCD admin password
    kubectl -n ${var.argocd_namespace} get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d
    
    # STEP 7: Access ArgoCD UI (port-forward)
    kubectl port-forward -n ${var.argocd_namespace} svc/argocd-server 8080:443
    # Then open: https://localhost:8080
    # Username: admin
    # Password: (from step 7)
    
    # STEP 8: Verify ArgoCD applications
    kubectl get applications -n ${var.argocd_namespace}
    
    # ========================================
    # GITOPS WORKFLOW (after initial setup)
    # ========================================
    # 1. Code push to main branch
    # 2. GitHub Actions builds images
    # 3. Images pushed to private ECR
    # 4. Helm values updated with new image tags
    # 5. ArgoCD syncs changes automatically
    # 6. Application deployed with latest images
  EOT
}

