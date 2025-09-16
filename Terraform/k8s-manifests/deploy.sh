#!/bin/bash
set -e

if ! kubectl get nodes &> /dev/null; then
  echo "kubectl not configured. Run: aws eks update-kubeconfig --region us-east-1 --name microservices-cluster"
  exit 1
fi

echo "Applying Kubernetes manifests..."
kubectl apply -f namespace.yaml
kubectl apply -f deployment.yaml
kubectl apply -f service.yaml
kubectl apply -f ingress.yaml

echo "Waiting for deployment to be ready..."
kubectl wait --for=condition=available --timeout=300s deployment/microservices-app -n microservices

echo "Service details:"
kubectl get service microservices-service -n microservices

