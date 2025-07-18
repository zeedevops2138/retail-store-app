##  Architecture Diagram for Creating Application


### Resources Created usng Terraform

A fully automated, production-ready infrastructure and deployment pipeline for a microservices-based Application using:

- **VPC** (Subnets, Route Tables, IGW, NAT Gateway)
- **Amazon EKS** (Elastic Kubernetes Service)
- **EKS IAM Roles**
- **Security Groups**
- **Bastion Host** for secure Kubernetes cluster access
- **Docker** for containerization
- **Argo CD** for GitOps-based automated deployment

## Quickstart

The following sections provide quickstart instructions for various platforms.


### Step 1: Terraform

Run the following to create the entire Infrastructure

```
terraform init
terraform plan
terraform apply --auto-approve
```

## Step 2: ECR-Repository Creation
Run the following Command to create Repositories in ECR:
```
aws ecr create-repository --repository-name your-repo-name --region your-region
```
<img width="2940" height="1059" alt="image" src="https://github.com/user-attachments/assets/5305275c-b55a-47ae-b8dd-d22fa1d9582e" />

### Step 3: GitHub Actions

Use GitHub Actions to build Docker images and push to ECR

**Create an IAM User, provide required policies, and Generate Credentails**

**Go to your GitHub repo → Settings → Secrets and variables → Actions → New repository secret.**
| Secret Name           | Value                              |
|-----------------------|------------------------------------|
| `AWS_ACCESS_KEY_ID`   | *Your AWS Access Key ID*           |
| `AWS_SECRET_ACCESS_KEY` | *Your AWS Secret Access Key*     |
| `AWS_REGION`          | `region-name`                       |
| `ECR_REGISTRY`        | `your-account-id.dkr.ecr.ap-south-1.amazonaws.com` |






