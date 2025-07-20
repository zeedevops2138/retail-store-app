data "aws_region" "current" {}

output "configure_kubectl" {
  description = "Command to update kubeconfig for this cluster"
  value       = "aws eks --region ${data.aws_region.current.name} update-kubeconfig --name ${module.retail_app_eks.cluster_name}"
}

output "bastion_public_ip" {
  description = "Public IP of the bastion host"
  value       = aws_instance.bastion.public_ip
}

output "bastion_ssh_command" {
  description = "SSH command to connect to the bastion host"
  value       = "ssh -i ${path.module}/keys/bastion_key.pem ubuntu@${aws_instance.bastion.public_ip}"
}

output "cluster_info" {
  description = "Information about the EKS cluster"
  value = {
    cluster_name = module.retail_app_eks.cluster_name
    cluster_endpoint = module.retail_app_eks.cluster_endpoint
    cluster_version = module.retail_app_eks.cluster_version
  }
}

output "ssh_key_info" {
  description = "Information about the generated SSH keys"
  value = {
    private_key_path = "${path.module}/keys/bastion_key.pem"
    public_key_path  = "${path.module}/keys/bastion_key.pub"
    key_name         = aws_key_pair.bastion.key_name
  }
}

output "bastion_connection_info" {
  description = "Complete connection information for the bastion"
  value = {
    public_ip = aws_instance.bastion.public_ip
    ssh_command = "ssh -i ${path.module}/keys/bastion_key.pem ubuntu@${aws_instance.bastion.public_ip}"
    key_location = "Keys generated in: ${path.module}/keys/"
    cluster_config_command = "aws eks --region ${data.aws_region.current.name} update-kubeconfig --name ${module.retail_app_eks.cluster_name}"
  }
}

output "bastion_eks_test_instructions" {
  description = "Step-by-step instructions to test EKS access from bastion"
  value = <<-EOT
    # 1. SSH to bastion:
    ssh -i ${path.module}/keys/bastion_key.pem ubuntu@${aws_instance.bastion.public_ip}
    
    # 2. Configure AWS credentials (if not already configured):
    aws configure
    
    # 3. Update kubeconfig for the cluster:
    aws eks --region ${data.aws_region.current.name} update-kubeconfig --name ${module.retail_app_eks.cluster_name}
    
    # 4. Test kubectl access:
    kubectl get nodes
    kubectl get pods --all-namespaces
    
    # 5. Test cluster connectivity:
    kubectl cluster-info
  EOT
}

# NGINX Ingress Controller outputs
output "nginx_ingress_controller_info" {
  description = "Information about NGINX Ingress Controller"
  value = {
    namespace = "ingress-nginx"
    service_name = "ingress-nginx-controller"
    check_status_command = "kubectl get svc -n ingress-nginx ingress-nginx-controller"
    get_external_ip_command = "kubectl get svc -n ingress-nginx ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'"
  }
}

output "application_access_info" {
  description = "Information to access the retail store application"
  value = {
    ingress_namespace = "retail-store"
    ingress_name = "ui"
    check_ingress_command = "kubectl get ingress -n retail-store"
    get_ingress_hostname = "kubectl get ingress -n retail-store ui -o jsonpath='{.spec.rules[0].host}'"
    port_forward_command = "kubectl port-forward -n retail-store svc/ui 8080:80"
    nginx_loadbalancer_command = "kubectl get svc -n ingress-nginx ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'"
    access_via_nginx = "Use the LoadBalancer hostname from nginx_loadbalancer_command to access the application"
  }
}

# NGINX Ingress endpoint (will be available after deployment)
output "nginx_ingress_endpoint" {
  description = "NGINX Ingress Controller LoadBalancer endpoint"
  value = {
    get_endpoint_command = "kubectl get svc -n ingress-nginx ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'"
    access_note = "The retail store UI will be accessible via this LoadBalancer endpoint once ArgoCD deploys the application"
    verify_command = "curl http://$(kubectl get svc -n ingress-nginx ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')"
  }
}

output "argocd_access_info" {
  description = "Information to access ArgoCD"
  value = {
    namespace = var.argocd_namespace
    service_name = "argocd-server"
    port_forward_command = "kubectl port-forward -n ${var.argocd_namespace} svc/argocd-server 8080:443"
    get_admin_password = "kubectl -n ${var.argocd_namespace} get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d"
    admin_username = "admin"
    access_url = "https://localhost:8080"
  }
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
    
    # STEP 3: Run terraform apply (this will install ArgoCD and NGINX Ingress)
    # terraform apply
    
    # STEP 4: Verify NGINX Ingress Controller installation
    kubectl get pods -n ingress-nginx
    kubectl get svc -n ingress-nginx
    
    # STEP 5: Get NGINX Load Balancer external IP/hostname
    kubectl get svc -n ingress-nginx ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
    
    # STEP 6: Verify ArgoCD installation
    kubectl get pods -n ${var.argocd_namespace}
    kubectl get svc -n ${var.argocd_namespace}
    
    # STEP 7: Get ArgoCD admin password
    kubectl -n ${var.argocd_namespace} get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d
    
    # STEP 8: Access ArgoCD UI (port-forward)
    kubectl port-forward -n ${var.argocd_namespace} svc/argocd-server 8080:443
    # Then open: https://localhost:8080
    # Username: admin
    # Password: (from step 7)
    
    # STEP 9: Verify ArgoCD applications
    kubectl get applications -n ${var.argocd_namespace}
    
    # STEP 10: Monitor application deployment
    kubectl get pods -n retail-store
    kubectl get ingress -n retail-store
    
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

# ArgoCD credentials output
output "argocd_credentials" {
  description = "ArgoCD access credentials and commands"
  value = {
    username = "admin"
    password_command = "kubectl -n ${var.argocd_namespace} get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d"
    port_forward_command = "kubectl port-forward -n ${var.argocd_namespace} svc/argocd-server 8080:443"
    access_url = "https://localhost:8080"
    namespace = var.argocd_namespace
  }
}
