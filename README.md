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


### Resources Created using Terraform

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


### Step 1: Terraform

Run the following to create the entire Infrastructure

```
terraform init
terraform plan
terraform apply --auto-approve
```

Configure kubectl to Access EKS
```
aws eks update-kubeconfig --name <your-eks-cluster-name>
kubectl get nodes 
```

## Step 2: ECR-Repository Creation
Run the following Command to create Repositories in ECR:
```
aws ecr create-repository --repository-name <your-repo-name > --region <repo-region>
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

## Step 4: Argo CD Automated Deployment
Argo CD (Continuous Integration) Installation
```
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
```

## Port-forward to Argo CD UI and login
```
kubectl port-forward svc/argocd-server -n argocd 8080:443
```
<img width="2911" height="1595" alt="image" src="https://github.com/user-attachments/assets/a0a4c296-580f-431b-8b9f-0e268c8c27f5" />


