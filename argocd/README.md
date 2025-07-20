# ArgoCD Setup for Retail Store Application

This directory contains ArgoCD application manifests for deploying the retail store sample application to Kubernetes.

## Directory Structure

```
argocd/
├── projects/
│   └── retail-store-project.yaml    # ArgoCD project configuration
├── applications/
│   ├── retail-store-app.yaml        # Main application (sync wave 0)
│   ├── retail-store-cart.yaml       # Cart service (sync wave 1)
│   ├── retail-store-catalog.yaml    # Catalog service (sync wave 1)
│   ├── retail-store-checkout.yaml   # Checkout service (sync wave 1)
│   ├── retail-store-orders.yaml     # Orders service (sync wave 1)
│   └── retail-store-ui.yaml         # UI service (sync wave 2)
└── README.md
```

## Sync Waves

The applications are deployed in the following order using sync waves:

1. **Wave 0**: Main application infrastructure
2. **Wave 1**: Backend services (cart, catalog, checkout, orders)
3. **Wave 2**: Frontend service (UI)

## Prerequisites

1. **ArgoCD Installed**: ArgoCD must be installed in your Kubernetes cluster
2. **GitHub Repository**: The repository must be accessible to ArgoCD
3. **AWS ECR**: Private ECR repositories must be created for each service
4. **IAM Permissions**: Proper IAM roles and policies for ECR access

## Required AWS ECR Repositories

Create the following private ECR repositories:

```bash
aws ecr create-repository --repository-name retail-cart
aws ecr create-repository --repository-name retail-catalog
aws ecr create-repository --repository-name retail-checkout
aws ecr create-repository --repository-name retail-orders
aws ecr create-repository --repository-name retail-ui
```

## GitHub Secrets

Configure the following secrets in your GitHub repository:

- `AWS_ROLE_ARN`: ARN of the IAM role for GitHub Actions
- `AWS_ACCOUNT_ID`: Your AWS account ID
- `AWS_REGION`: AWS region (e.g., us-east-1)

## IAM Role Policy

The IAM role used by GitHub Actions should have the following policy:

```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "ecr:GetAuthorizationToken",
                "ecr:BatchCheckLayerAvailability",
                "ecr:GetDownloadUrlForLayer",
                "ecr:BatchGetImage",
                "ecr:PutImage",
                "ecr:InitiateLayerUpload",
                "ecr:UploadLayerPart",
                "ecr:CompleteLayerUpload"
            ],
            "Resource": "arn:aws:ecr:*:*:repository/retail-*"
        },
        {
            "Effect": "Allow",
            "Action": "ecr:GetAuthorizationToken",
            "Resource": "*"
        }
    ]
}
```

## Deployment

1. **Apply ArgoCD Project**:
   ```bash
   kubectl apply -f argocd/projects/retail-store-project.yaml
   ```

2. **Apply ArgoCD Applications**:
   ```bash
   kubectl apply -f argocd/applications/
   ```

3. **Monitor Deployment**:
   ```bash
   kubectl get applications -n argocd
   ```

## Workflow

1. **Code Push**: When code is pushed to the main branch
2. **GitHub Actions**: Builds Docker images and pushes to private ECR
3. **Helm Update**: Updates values.yaml files with new image tags
4. **Git Commit**: Commits changes back to the repository
5. **ArgoCD Sync**: Detects changes and deploys to Kubernetes

## Troubleshooting

### Check Application Status
```bash
kubectl get applications -n argocd
kubectl describe application retail-store-app -n argocd
```

### Check Pod Status
```bash
kubectl get pods -n retail-store
kubectl describe pod <pod-name> -n retail-store
```

### Check Logs
```bash
kubectl logs <pod-name> -n retail-store
```

### Manual Sync
```bash
kubectl patch application retail-store-app -n argocd --type='merge' -p='{"spec":{"syncPolicy":{"automated":{"prune":true,"selfHeal":true}}}}'
``` 