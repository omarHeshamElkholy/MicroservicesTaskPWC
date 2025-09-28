# End-to-End Microservice Deployment Runbook

This runbook documents the exact steps followed to containerize a Python microservice, provision the required AWS infrastructure with Terraform, deploy to Kubernetes, expose the workload publicly, automate delivery with CodeBuild, and layer in monitoring via Prometheus/Grafana. The same workflow can be adapted to other cloud providers (the original request preferred Azure), but the implementation described here targets AWS.

## 1. Clone the Source Repository

```bash
git clone https://github.com/sameh-Tawfiq/Microservices.git
cd Microservices
```

> The working tree in this project copies the service code into `app/` and supplements it with infrastructure, CI/CD, and monitoring assets.

## 2. Dockerize the Application

1. Review `Dockerfile` (root of the repo). It builds a slim Python 3.11 image, installs requirements, copies the Flask service, and exposes port `8000`.
2. Build and test locally:
   ```bash
   docker build -t microservices-app:local .
   docker run --rm -p 8000:8000 microservices-app:local
   curl http://localhost:8000/users
   ```
3. Push to Amazon ECR (performed automatically in the CI/CD pipeline, but the manual steps are):
   ```bash
   aws ecr get-login-password --region us-east-1 \
     | docker login --username AWS --password-stdin $ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com
   docker tag microservices-app:local $ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com/microservices-app:latest
   docker push $ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com/microservices-app:latest
   ```

## 3. Provision the Kubernetes Cluster with Terraform (AWS EKS)

1. Ensure prerequisites: Terraform ≥ 1.4, AWS CLI, kubectl, and an S3 bucket `tfbackendz3` for remote state.
2. Review Terraform layout under `Terraform/`:
   - `main.tf` wires the `k8s-cluster` and `ci-cd` modules.
   - `providers.tf` configures AWS, Kubernetes, and Helm providers with the S3 backend.
   - `variables.tf` holds tunables (cluster name, instance types, CodeBuild project name, etc.).
3. Initialize and plan:
   ```bash
   terraform -chdir=Terraform init
   terraform -chdir=Terraform plan
   ```
4. Apply to create the EKS control plane, node group (three `t3.small` nodes), IAM roles, and supporting resources:
   ```bash
   terraform -chdir=Terraform apply
   ```
5. Export cluster credentials:
   ```bash
   aws eks update-kubeconfig --region us-east-1 --name microservices-cluster
   kubectl get nodes
   ```

> The Terraform module originally requested Azure; swapping the AWS provider for an AzureRM-backed module will achieve that with the same structure.

## 4. Deploy the Microservice to Kubernetes

1. Kubernetes manifests reside in `Terraform/k8s-manifests/`:
   - `namespace.yaml`
   - `deployment.yaml`
   - `service.yaml`
   - `ingress.yaml`
2. Apply them after the cluster is ready:
   ```bash
   kubectl apply -f Terraform/k8s-manifests/namespace.yaml
   kubectl apply -f Terraform/k8s-manifests/deployment.yaml
   kubectl apply -f Terraform/k8s-manifests/service.yaml
   kubectl apply -f Terraform/k8s-manifests/ingress.yaml
   kubectl wait --for=condition=available deployment/microservices-app -n microservices --timeout=5m
   ```
3. Validate:
   ```bash
   kubectl get pods -n microservices
   kubectl get svc -n microservices microservices-service
   ```

## 5. Expose the Service to the Internet

- `service.yaml` defines a `LoadBalancer` Service; AWS provisions an ELB and returns its hostname.
- Retrieve the external address:
  ```bash
  kubectl get svc microservices-service -n microservices -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
  ```
- Hit the public endpoints, e.g. `http://<elb-hostname>/users` and `/products`.

## 6. Implement CI/CD with AWS CodeBuild

1. The pipeline definition lives under `Terraform/ci-cd/`:
   - Creates an ECR repository, CodeBuild project, IAM roles, and CloudWatch log group.
   - Injects repository URL, branch, and Terraform backend configuration via variables.
2. `buildspec.yml` drives the build:
   - Installs Terraform and kubectl.
   - Runs `terraform init/plan/apply` (using the repo’s Terraform directory).
   - Builds and pushes the Docker image to ECR.
   - Applies Kubernetes manifests and waits for rollout.
3. Trigger a build manually:
   ```bash
   aws codebuild start-build --project-name microservices-cicd
   aws codebuild batch-get-builds --ids microservices-cicd:<build-id>
   ```
4. A successful run produces the image, updates the deployment, and logs results to `/aws/codebuild/microservices-cicd`.

## 7. Add Monitoring (Prometheus & Grafana)

1. Monitoring configuration sits in `Terraform/monitoring.tf` with Helm values in `Terraform/monitoring-values.yaml`.
2. Terraform provisions a `monitoring` namespace and installs the `kube-prometheus-stack` Helm chart (Prometheus, Grafana, Alertmanager, kube-state-metrics, and node exporters).
3. Grafana is exposed via LoadBalancer:
   ```bash
   terraform -chdir=Terraform output grafana_service_hostname
   # or
   kubectl get svc -n monitoring kube-prometheus-stack-grafana
   ```
4. Default credentials (`admin / changeme`) are defined in `monitoring-values.yaml`; change them immediately for production.
5. Built-in dashboards (Nodes, Pods, Kubernetes/Compute Resources) are pre-loaded. Add custom dashboards or configure application metrics by exposing `/metrics` endpoints.

## 8. Clean Up (Optional)

To avoid ongoing costs when testing is complete:

```bash
terraform -chdir=Terraform destroy
# If ECR contains images, remove them first:
aws ecr list-images --repository-name microservices-app
aws ecr batch-delete-image --repository-name microservices-app --image-ids imageTag=<tag>
terraform -chdir=Terraform destroy
```

Also delete the Terraform state file in S3 (`tfbackendz3/terraform.tfstate`) if you no longer need it.

---

## Key Repository Paths

- `Dockerfile`, `requirements.txt`, `run.py` – application container assets
- `Terraform/` – infrastructure-as-code for EKS, CodeBuild, and monitoring
- `Terraform/k8s-manifests/` – raw Kubernetes YAML for the microservice
- `buildspec.yml` – CodeBuild pipeline definition

This README serves as the reproducible playbook for rebuilding the environment from scratch, adapting it to other clouds, and understanding how each piece fits together.
