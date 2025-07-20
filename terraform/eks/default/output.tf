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
