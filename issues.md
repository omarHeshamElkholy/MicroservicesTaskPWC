# Issues and Resolutions

This document captures the problems discovered while building and deploying the service, along with the fixes applied.

## 1. Local Environment and App Startup
- **Issue**: Flask/Werkzeug incompatibility caused `ImportError: cannot import name 'url_quote'`.
- **Fix**: Pin Flask 2.2.2 with Werkzeug 2.2.3 and reinstall requirements.
- **Issue**: App bound to default port 5000, conflicting with local macOS services.
- **Fix**: Update `run.py` to listen on port 8000 and bind to `0.0.0.0`.

## 2. Dockerization
- **Enhancements**: Non-root user, real-time logging configuration, trimmed apt cache, and a `/users` healthcheck.
- **Issue**: Image size ~800 MB.
- **Fix**: Recommend multi-stage builds or an Alpine base image; ensure `.dockerignore` excludes artifacts.

## 3. Kubernetes via Terraform (EKS)
- **Issue**: Unsupported AZ (e.g., `us-east-1e`) for the control plane.
- **Fix**: Filter to supported AZs (`a/b/c/d/f`).
- **Issue**: `Too many pods` on `t3.micro` nodes.
- **Fix**: Scale the node group to three `t3.small` instances.
- **Issue**: `no match for platform in manifest` when pushing arm64 images.
- **Fix**: Build with `--platform linux/amd64` before pushing to ECR.

## 4. CI/CD and Terraform Automation
- **Issue**: CodeBuild lacked permissions for S3, ECR, IAM, EC2, and CloudWatch.
- **Fix**: Expand the inline IAM policy with required read/write permissions.
- **Issue**: `kubectl` in CodeBuild reported `You must be logged in to the server`.
- **Fix**: Manage the `aws-auth` ConfigMap via Terraform to map worker and CodeBuild roles.

## 5. Monitoring Rollout
- **Issue**: Monitoring pods were stuck in Pending due to limited node capacity.
- **Fix**: Increase node group size and instance type (see section 3).
- **Info**: Grafana exposed through an ELB with default credentials `admin/changeme` (set in `monitoring-values.yaml`); rotate before production use.
