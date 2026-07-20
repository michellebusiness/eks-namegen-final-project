# Random Name Generator on Amazon EKS

This final project deploys a Node.js Random Name Generator and Saver application to Amazon Elastic Kubernetes Service (EKS). The application generates random names, stores them in MongoDB, and displays the saved names through a web interface.

The solution uses Terraform for AWS infrastructure, Kubernetes manifests for the workloads, an internet-facing Network Load Balancer (NLB), Amazon ECR for container images, and GitHub Actions with OIDC for continuous deployment.

## Project Requirements

| Requirement | Implementation |
| --- | --- |
| Infrastructure as Code | Terraform |
| Kubernetes platform | Amazon EKS Auto Mode |
| CI/CD | GitHub Actions |
| Container registry | Amazon ECR |
| External access | Internet-facing AWS NLB |
| Database topology | MongoDB 3.6 StatefulSet |
| Persistent storage | PVC backed by an encrypted `gp3` EBS volume |
| AWS authentication from GitHub | OIDC federation; no long-lived AWS keys |

## Architecture

The application runs in the `namegen` Kubernetes namespace. The NLB forwards public traffic to two Node.js application replicas. The application connects to the internal MongoDB service. MongoDB runs as a StatefulSet and stores its data on a persistent EBS volume.

The CI/CD pipeline is triggered by a push to `main`. GitHub Actions assumes an AWS IAM role through OIDC, builds the container image, pushes versioned and `latest` tags to ECR, applies the Kubernetes manifests, updates the Deployment image, and waits for the rollout to complete.

[Open the editable draw.io architecture and CI/CD diagram](architecture/namegen-architecture.drawio)

## Repository Structure

```text
.
|-- .github/workflows/deploy.yml    # Build and deployment workflow
|-- architecture/                   # draw.io architecture diagram
|-- k8s/                            # Kubernetes manifests
|-- screenshots/                    # Project evidence
|-- terraform/                      # AWS infrastructure as code
|-- Dockerfile                      # Application container image
|-- compose.yaml                    # Optional local environment
|-- mongo-init.js                   # Local MongoDB initialization
|-- package.json
|-- server.js
`-- README.md
```

## AWS Resources

Terraform creates the following main resources in `eu-central-1`:

- A VPC across two Availability Zones
- Public and private subnets
- Internet Gateway and a lab-sized single NAT Gateway configuration
- Amazon EKS Auto Mode cluster named `namegen-eks-auto`
- Amazon ECR repository named `namegen`
- GitHub Actions IAM role and GitHub OIDC trust configuration
- Required IAM roles, policies, route tables, and security-related resources

## Kubernetes Workloads

- `namegen-app`: Node.js Deployment with two replicas
- `namegen-service`: `LoadBalancer` Service using `eks.amazonaws.com/nlb`
- `mongodb`: MongoDB 3.6 StatefulSet with one replica
- Internal MongoDB ClusterIP and headless Services
- Encrypted `gp3` StorageClass and a 5 Gi PersistentVolumeClaim
- Kubernetes Secret for MongoDB credentials
- ConfigMap that initializes the application database and user

The application uses this connection format:

```text
MONGODB_URL=mongodb://genuser:<password>@mongodb/namegen
```

The password is loaded from a Kubernetes Secret and is not committed to the repository.

## Prerequisites

- An AWS account with permissions to create the required resources
- AWS CLI v2
- Terraform
- Docker
- `kubectl`
- Git
- A GitHub repository with Actions enabled

Configure an AWS CLI profile and confirm the active identity before deploying:

```powershell
$env:AWS_PROFILE = "namegen-admin"
aws sts get-caller-identity
aws configure get region
```

## Local Development with Docker Compose

Build and start the application and MongoDB locally:

```powershell
docker compose up --build -d
docker compose ps
```

Open `http://localhost:8080`, then stop the environment when finished:

```powershell
docker compose down
```

## Provision the AWS Infrastructure

From the repository root:

```powershell
cd terraform
terraform init
terraform fmt -check
terraform validate
terraform plan -out tfplan
terraform apply tfplan
```

Terraform outputs the cluster name, ECR repository URL, GitHub Actions role ARN, VPC ID, and private subnet IDs.

Configure `kubectl` after the apply completes:

```powershell
aws eks update-kubeconfig `
  --region eu-central-1 `
  --name namegen-eks-auto `
  --profile namegen-admin

kubectl get nodes
```

## GitHub Actions Configuration

Create these GitHub Actions repository secrets:

- `MONGODB_ROOT_PASSWORD`
- `MONGODB_APP_PASSWORD`

Do not store the secret values in source control.

The workflow receives temporary AWS credentials through GitHub OIDC. The IAM trust policy is restricted to this repository and the `main` branch. GitHub's immutable organization and repository IDs are included in the OIDC subject condition so the trust remains unambiguous.

Every push to `main` runs the deployment workflow:

1. Check out the source code.
2. Assume the AWS deployment role through OIDC.
3. Authenticate to Amazon ECR.
4. Build the Docker image.
5. Push both the commit SHA tag and `latest` tag.
6. Update the EKS kubeconfig.
7. Create or update the MongoDB Kubernetes Secret.
8. Apply all Kubernetes manifests.
9. Set the application image to the immutable commit SHA.
10. Wait for the application and MongoDB rollouts.

## Manual Kubernetes Deployment

The GitHub Actions workflow performs these operations automatically. For troubleshooting, the manifests can also be applied manually:

```powershell
kubectl apply -f k8s/namespace.yaml

kubectl -n namegen create secret generic mongodb-secret `
  --from-literal=MONGO_INITDB_ROOT_USERNAME=root `
  --from-literal=MONGO_INITDB_ROOT_PASSWORD='<root-password>' `
  --from-literal=MONGO_APP_USERNAME=genuser `
  --from-literal=MONGO_APP_PASSWORD='<app-password>' `
  --dry-run=client -o yaml | kubectl apply -f -

kubectl apply -f k8s/
```

## Verify the Deployment

Check the resources and rollout status:

```powershell
kubectl get pods,svc,pvc -n namegen
kubectl rollout status deployment/namegen-app -n namegen
kubectl rollout status statefulset/mongodb -n namegen
```

Get the public application address:

```powershell
kubectl get service namegen-service -n namegen `
  -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
```

Open the returned NLB hostname in a browser. The address is dynamically assigned by AWS and can change if the Service is recreated.

Useful application endpoints:

- `/` - web interface
- `/api/random_name` - generate a random name
- `/api/names` - retrieve, save, or delete names
- `/api/connection` - display MongoDB connection information

## Persistent Storage Test

To demonstrate that MongoDB data survives a Pod replacement:

1. Save one or more names in the web application.
2. Delete the MongoDB Pod:

   ```powershell
   kubectl delete pod mongodb-0 -n namegen
   ```

3. Wait for the StatefulSet to recreate it:

   ```powershell
   kubectl rollout status statefulset/mongodb -n namegen
   ```

4. Refresh the application and confirm that the saved names are still present.

The data remains available because the replacement Pod mounts the same PersistentVolumeClaim.

## Screenshots

Deployment evidence, including the running application and AWS/Kubernetes resources, is available in the [screenshots folder](screenshots/).

## Security Notes

- GitHub Actions uses short-lived OIDC credentials instead of stored AWS access keys.
- MongoDB credentials are stored in GitHub Actions and Kubernetes Secrets.
- EBS storage is encrypted.
- MongoDB is exposed only inside the Kubernetes cluster.
- Only the application Service is exposed publicly through the NLB.
- IAM permissions are scoped to the CI/CD deployment workflow.

> MongoDB 3.6 is used only because it is required by the project specification. It is an obsolete release and should not be selected for a new production system.

## Cleanup

AWS resources generate costs. After the project has been reviewed and all screenshots have been saved, remove the Kubernetes resources first so AWS can delete the NLB and EBS volume:

```powershell
kubectl delete namespace namegen
```

Wait until the load balancer is deleted, then destroy the Terraform infrastructure:

```powershell
cd terraform
terraform destroy
```

Review the Terraform destruction plan carefully before confirming it.

## References

- [Original application source](https://github.com/redhat-developer-demos/namegen)
- [Terraform AWS Provider documentation](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [Amazon EKS documentation](https://docs.aws.amazon.com/eks/latest/userguide/getting-started.html)
- [GitHub Actions workflow syntax](https://docs.github.com/en/actions/reference/workflows-and-actions/workflow-syntax)
- [GitHub Markdown guide](https://docs.github.com/en/get-started/writing-on-github/getting-started-with-writing-and-formatting-on-github/basic-writing-and-formatting-syntax)

## License

The application source is based on the Red Hat Developer Demos Namegen project and retains its original MIT license.