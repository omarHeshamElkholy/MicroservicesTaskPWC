# MicroservicesTaskPWC — Issues and Resolutions

This document summarizes the issues encountered while running, containerizing, and deploying the Flask microservice, along with the fixes applied and final run instructions.

## 1) Local Environment and App Startup

- Problem: `pip` unavailable due to externally managed Python (PEP 668)
  - Resolution: Create and use a virtual environment
    - Commands:
      - `python3 -m venv venv`
      - `source venv/bin/activate`

- Problem: Flask/Werkzeug version mismatch causing ImportError:
  - Error: `ImportError: cannot import name 'url_quote' from 'werkzeug.urls'`
  - Cause: Flask 2.2.2 with newer Werkzeug (3.x)
  - Resolution: Pin Werkzeug to a compatible version
    - `requirements.txt`:
      - `Flask==2.2.2`
      - `Werkzeug==2.2.3`
    - Reinstall: `pip install --upgrade -r requirements.txt`

- Problem: App binding to wrong/default port (5000) and port conflicts
  - Cause: `run.py` used default `app.run()` (5000)
  - Resolution: Updated to `app.run(host='0.0.0.0', port=8000)` to match `app/main.py`

- Problem: `__pycache__` and editor artifacts committed
  - Resolution: Added `.gitignore` to exclude caches, venvs, IDE files

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

- Run with Docker
  - Build: `docker build -t microservices-app .`
  - Run: `docker run -p 8000:8000 microservices-app`

## 3) Kubernetes with Terraform (EKS)

- Problem: EKS UnsupportedAvailabilityZoneException (e.g., `us-east-1e` unsupported for control plane)
  - Resolution: Filter subnets to supported AZs only (e.g., a/b/c/d/f) in `main.tf`

- Problem: t3.micro pod capacity very small → Pods Pending: `Too many pods`
  - Resolution options applied:
    - Reduce replicas to `1` and lower resource requests/limits
    - Optionally increase node group desired size via Terraform

- Problem: ImagePullBackOff for `microservices-app:latest`
  - Cause: Nodes cannot access local Docker daemon images
  - Resolution: Use ECR
    - Create ECR: `aws ecr create-repository --repository-name microservices-app --region us-east-1`
    - Login: `aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin <ACCOUNT_ID>.dkr.ecr.us-east-1.amazonaws.com`
    - Build & tag: `docker build -t <ACCOUNT_ID>.dkr.ecr.us-east-1.amazonaws.com/microservices-app:latest .`
    - Push: `docker push <ACCOUNT_ID>.dkr.ecr.us-east-1.amazonaws.com/microservices-app:latest`
    - Update deployment image to the ECR URI

- Problem: `no match for platform in manifest`
  - Cause: Built on Apple Silicon (arm64) while EKS nodes are amd64
  - Resolution: Build for amd64 explicitly:
    - `docker build --platform linux/amd64 -t <ECR_URI>:latest .`
    - `docker push <ECR_URI>:latest`

- Apply K8s manifests (namespace, deployment, service, ingress)
  - From `Terraform/k8s-manifests/`:
    - `kubectl apply -f namespace.yaml`
    - `kubectl apply -f ecr-deployment.yaml` (uses ECR image)
    - `kubectl apply -f service.yaml` (type LoadBalancer)
    - `kubectl apply -f ingress.yaml` (optional ALB ingress)

## 4) Deploy Script Fixes (`Terraform/k8s-manifests/deploy.sh`)

- Fixed working-directory assumptions (build at repo root, return to manifests dir)
- Fixed manifest paths (use current dir)
- Added readiness wait and output of LoadBalancer hostname

## 5) Final Verification

- Check nodes: `kubectl get nodes`
- Check pods: `kubectl get pods -n microservices`
- Check service: `kubectl get svc -n microservices`
- Access service via:
  - `http://<loadbalancer-hostname>/users`
  - `http://<loadbalancer-hostname>/products`

## Notes and Tips

- Cost control: use `ON_DEMAND` t3.micro with minimal replicas; delete cluster when done
- If pods Pending with `Too many pods`, reduce replicas/resources or add a node
- If image pulls fail on EKS, verify:
  - Image exists in ECR and policy allows pull
  - Platform matches node arch (`linux/amd64`)
  - Node has network and IAM permissions