# MicroservicesTaskPWC — Issues and Resolutions

This document summarizes the issues encountered while running, containerizing, and deploying the Flask microservice, along with the fixes applied and final run instructions.

## 1) Local Environment and App Startup

- Problem: Flask/Werkzeug version mismatch causing ImportError:
  - Error: `ImportError: cannot import name 'url_quote' from 'werkzeug.urls'`
  - Cause: Flask 2.2.2 with newer Werkzeug (3.x)
  - Resolution: Pin Werkzeug to a compatible version
    - `requirements.txt`:
      - `Flask==2.2.2`
      - `Werkzeug==2.2.3`
    - Reinstall: `pip install --upgrade -r requirements.txt`

- Problem: App binding to wrong/default port (5000) and port conflicts due to working locally on a mac (port is used in airdrop)
  - Cause: `run.py` used default `app.run()` (5000)
  - Resolution: Updated to `app.run(host='0.0.0.0', port=8000)` to match `app/main.py`

## 2) Dockerization

- Additions in Dockerfile
  - Non-root user for security (`USER appuser`)
  - `PYTHONDONTWRITEBYTECODE=1` (avoid .pyc) and `PYTHONUNBUFFERED=1` (real-time logs)
  - Clean apt metadata (`rm -rf /var/lib/apt/lists/*`) to keep image smaller
  - Healthcheck hitting `/users`

- Problem: Large image size (~800MB)
  - Causes: base image + build tools (gcc) + Python deps
  - Improvements (future):
    - Use `--platform linux/amd64` only when required
    - Consider `python:3.11-alpine` (validate deps) or multi-stage builds to drop build toolchain
    - Ensure `.dockerignore` excludes venvs, caches, docs


## 3) Kubernetes with Terraform (EKS)

- Problem: EKS UnsupportedAvailabilityZoneException (e.g., `us-east-1e` unsupported for control plane)
  - Resolution: Filter subnets to supported AZs only (e.g., a/b/c/d/f) in `main.tf`

- Problem: t3.micro pod capacity very small → Pods Pending: `Too many pods`
  - Resolution options applied:
    - Reduce replicas to `1` and lower resource requests/limits
    - Optionally increase node group desired size via Terraform

- Problem: `no match for platform in manifest`
  - Cause: Built on Apple Silicon (arm64) while EKS nodes are amd64
  - Resolution: Build for amd64 explicitly:
    - `docker build --platform linux/amd64 -t <ECR_URI>:latest .`
    - `docker push <ECR_URI>:latest`

## 4) CI/CD & Terraform Automation Issues

- Problem: Terraform plan/apply in CodeBuild could not read remote state/backend objects
  - Errors: `AccessDeniedException` for `s3:GetObject`, `DescribeRepositories`, `GetRole`, `DescribeLogGroups`, `DescribeVpcs`, etc.
  - Resolution: Expanded the CodeBuild IAM inline policy to include read/list actions for ECR, IAM, CloudWatch Logs, EC2 metadata, S3 state bucket, and other Terraform-managed services.

- Problem: `kubectl` in CodeBuild returned `You must be logged in to the server`
  - Cause: The CodeBuild IAM role was not mapped into Kubernetes RBAC
  - Resolution: Manage the EKS `aws-auth` ConfigMap via Terraform, mapping
    - Worker node role → `system:bootstrappers`,`system:nodes`
    - CodeBuild role → `system:masters`
  - Implementation: Added Kubernetes provider + `kubernetes_config_map_v1.aws_auth` with the required role entries.

## 5) Final Verification

- Check nodes: `kubectl get nodes`
- Check pods: `kubectl get pods -n microservices`
- Check service: `kubectl get svc -n microservices`
- Access service via:
  - `http://<loadbalancer-hostname>/users`
  - `http://<loadbalancer-hostname>/products`

## 6) Monitoring Stack (Prometheus + Grafana)

- Stack: Terraform deploys the `kube-prometheus-stack` Helm chart (Prometheus, Alertmanager, Grafana, kube-state-metrics, node-exporter) to the `monitoring` namespace and exposes Grafana through a `LoadBalancer` service.
- Cluster capacity: The additional monitoring pods exceeded the `t3.micro` pod density limit. Scaling the EKS node group to three `t3.small` instances (with a max surge of +2) gives headroom for monitoring workloads and future app growth.
- Terraform outputs: After `terraform apply`, check `grafana_service_hostname` for the AWS ELB DNS name once the LoadBalancer is ready. You can also run `kubectl get svc -n monitoring kube-prometheus-stack-grafana`.
- Access Grafana: `http://<grafana-load-balancer>` with the default admin credentials from `monitoring-values.yaml` (`admin / changeme`). Rotate the password via Helm values or Kubernetes secret before production use.
- Application dashboards: Import the built-in Kubernetes and node dashboards or scrape custom `/metrics` from the microservice to visualize app-level metrics.
