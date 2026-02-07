# Kubernetes Deployment (RAG API + Redis)

## Why Kubernetes here

Use Kubernetes when you need:
- Horizontal scaling
- High availability
- Centralized observability/policy enforcement

Otherwise, App Service or Container Apps are simpler.

## Prerequisites

- A Kubernetes cluster (AKS or local)
- `kubectl` configured
- Container image for the RAG API

## Build and load image (local)

```bash
docker build -t rag-api:latest ./rag_api
```

If using AKS or a registry, push the image and update `image:` in [k8s/rag-api.yaml](k8s/rag-api.yaml).

## Deploy

```bash
kubectl apply -f k8s/namespace.yaml
kubectl apply -f k8s/redis.yaml
kubectl apply -f k8s/rag-api-config.yaml
kubectl apply -f k8s/rag-api-secret.yaml
kubectl apply -f k8s/rag-api.yaml
```

## Access

```bash
kubectl -n rag-system get svc rag-api
```

## Notes

- Secrets must be updated before deployment.
- For production, store secrets in Azure Key Vault + CSI driver.
