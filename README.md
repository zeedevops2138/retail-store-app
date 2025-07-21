# Infrastructure Deployment with Terraform and EKS(Auto Mode)
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

This is a sample application designed to illustrate various concepts related to containers on AWS. It presents a sample retail store application including a product catalog, shopping cart and checkout.

It provides:

- A demo store-front application with themes, pages to show container and application topology information, generative AI chat bot and utility functions for experimentation and demos.
- An optional distributed component architecture using various languages and frameworks
- A variety of different persistence backends for the various components like MariaDB (or MySQL), DynamoDB and Redis
- The ability to run in different container orchestration technologies like Docker Compose, Kubernetes etc.
- Pre-built container images for both x86-64 and ARM64 CPU architectures
- All components instrumented for Prometheus metrics and OpenTelemetry OTLP tracing
- Support for Istio on Kubernetes
- Load generator which exercises all of the infrastructure

See the [features documentation](./docs/features.md) for more information.

**This project is intended for educational purposes only and not for production use**

![Screenshot](/docs/images/screenshot.png)

## Application Architecture 

The application has been deliberately over-engineered to generate multiple de-coupled components. These components generally have different infrastructure dependencies, and may support multiple "backends" (example: Carts service supports MongoDB or DynamoDB).

![Architecture](/docs/images/architecture.png)

| Component                  | Language | Container Image                                                             | Helm Chart                                                                        | Description                             |
| -------------------------- | -------- | --------------------------------------------------------------------------- | --------------------------------------------------------------------------------- | --------------------------------------- |
| [UI](./src/ui/)            | Java     | [Link](https://gallery.ecr.aws/aws-containers/retail-store-sample-ui)       | [Link](https://gallery.ecr.aws/aws-containers/retail-store-sample-ui-chart)       | Store user interface                    |
| [Catalog](./src/catalog/)  | Go       | [Link](https://gallery.ecr.aws/aws-containers/retail-store-sample-catalog)  | [Link](https://gallery.ecr.aws/aws-containers/retail-store-sample-catalog-chart)  | Product catalog API                     |
| [Cart](./src/cart/)        | Java     | [Link](https://gallery.ecr.aws/aws-containers/retail-store-sample-cart)     | [Link](https://gallery.ecr.aws/aws-containers/retail-store-sample-cart-chart)     | User shopping carts API                 |
| [Orders](./src/orders)     | Java     | [Link](https://gallery.ecr.aws/aws-containers/retail-store-sample-orders)   | [Link](https://gallery.ecr.aws/aws-containers/retail-store-sample-orders-chart)   | User orders API                         |
| [Checkout](./src/checkout) | Node     | [Link](https://gallery.ecr.aws/aws-containers/retail-store-sample-checkout) | [Link](https://gallery.ecr.aws/aws-containers/retail-store-sample-checkout-chart) | API to orchestrate the checkout process |


##  Architecture Diagram for Creating Application


## 🧩 Prerequisites

Make sure you have the following tools installed:

- Terraform 
- AWS CLI configured (`aws configure`)
- `kubectl` and `eksctl`
- Docker


## 🔁 Fork or Clone the Repository

### 🔹 Fork the Repository

1. Go to the original GitHub repository:  
   `https://github.com/your-org/your-repo-name`
   
2. Click the **Fork** button at the top-right corner.

### 🔹 Clone Your Forked Repo

```bash
git clone https://github.com/your-username/your-repo-name.git
cd your-repo-name 
```


## Resources Created using Terraform

A fully automated, production-ready infrastructure and deployment pipeline for a microservices-based Application using:

- **VPC** (Subnets, Route Tables, IGW, NAT Gateway)
- **Amazon EKS** (Elastic Kubernetes Service)
- **EKS Auto Mode**
- **IAM Roles**
- **Security Groups**
- **Bastion Host** for secure Kubernetes cluster access
- **Docker** for containerization
- **Argo CD** for GitOps-based automated deployment

## Quickstart

The following sections provide quickstart instructions for various platforms.


## Step 1: Terraform

Run the following commands to create the entire Infrastructure

##### In 1st Phase:  Terraform Initializes and Creates the resources inside the retail_app_eks module (like EKS cluster, node groups, IAM roles).
```
terraform init
terraform apply -target=module.retail_app_eks 
```


## Step 2: Update kubeconfig to Access the EKS Cluster
```
aws eks update-kubeconfig --name retail-store --region ap-south-1
```

##### In 2nd Phase: Apply Remaining Configuration this will create (Kubernetes-related resources, Argo CD setup, Monitoring resources)
```
terraform apply --auto-approve
```
It takes approximately 15–20 minutes to create the cluster.

#### Check if the nodes are running
```
kubectl get nodes
```

<img width="1097" height="73" alt="image" src="https://github.com/user-attachments/assets/00c851d0-91a9-4e5e-a1c6-e8aac12a381e" />


## Step 3: GitHub Actions

Once the Entire Cluster is created use GitHub Actions to automatically build and push Docker images to ECR whenever you do changes to the repo github actions will be automatically triggered. 


For GitHub Actions first configure secrets so the pipelines can be automatically triggred:

**Create an IAM User, provide required policies, and Generate Credentails**

**Go to your GitHub repo → Settings → Secrets and variables → Actions → New repository secret.**

| Secret Name           | Value                              |
|-----------------------|------------------------------------|
| `AWS_ACCESS_KEY_ID`   | *Your AWS Access Key ID*           |
| `AWS_SECRET_ACCESS_KEY` | *Your AWS Secret Access Key*     |
| `AWS_REGION`          | `region-name`                       |
| `ECR_REGISTRY`        | `your-account-id.dkr.ecr.ap-south-1.amazonaws.com` |

 




## Step 4: Argo CD Automated Deployment

Argo CD (Continuous Integration) Installation

```
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
```

## Port-forward command for Argo CD UI and login

```
kubectl port-forward svc/argocd-server -n argocd 8080:443
```

## To get Default Argo CD Admin Password (after initial installation):

```
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
```

<img width="2909" height="1590" alt="image" src="https://github.com/user-attachments/assets/2cd76cea-da96-49ec-95e7-964babc2f313" />


## Verify Kubernetes Pods
```
kubectl get pods
```

## Verify Services 
```
kubectl get svc -n ui
```
<img width="2909" height="1764" alt="image" src="https://github.com/user-attachments/assets/cffbeda3-b212-481a-bc80-626547dd98b4" />
Trigger fresh build - Mon 21 Jul 2025 00:17:52 IST

### 🧹 Cleanup To delete the entire Infrastructure created by terraform

Run both the commands and wait for 10-15 minutes all the resources created with terraform will be deleted.

```
terraform destroy -target=module.retail_app_eks --auto-approve
terraform destroy --auto-approve
```


<img width="1339" height="509" alt="image" src="https://github.com/user-attachments/assets/85d80080-b4a9-4355-a618-9a59057e8e71" />

