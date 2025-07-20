# Wait for the cluster to be ready
resource "time_sleep" "wait_for_cluster" {
  create_duration = "30s"
  depends_on = [
    module.retail_app_eks,
    module.eks_blueprints_addons
  ]
}

resource "helm_release" "argocd" {
  name             = "argocd"
  namespace        = var.argocd_namespace
  create_namespace = true

  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  version    = var.argocd_chart_version

  values = [
    yamlencode({
      server = {
        service = {
          type = "ClusterIP"
        }
        ingress = {
          enabled = false
        }
      }
    })
  ]

  depends_on = [
    time_sleep.wait_for_cluster
  ]
}

# Wait for ArgoCD to be fully deployed
resource "time_sleep" "wait_for_argocd" {
  create_duration = "60s"
  depends_on = [helm_release.argocd]
}

resource "null_resource" "argocd_apps" {
  depends_on = [time_sleep.wait_for_argocd]
  provisioner "local-exec" {
    command = "kubectl apply -n ${var.argocd_namespace} -f ${path.module}/../../argocd/projects/ && kubectl apply -n ${var.argocd_namespace} -f ${path.module}/../../argocd/applications/"
  }
} 