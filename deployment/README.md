# Gateway GCP Deployment

## Architecture

```
GitHub Actions (CI/CD)
    │
    ▼ Workload Identity Federation (OIDC)
Artifact Registry (southamerica-east1)
    │
    ▼ docker pull
GKE Cluster
├── KrakenD (2+ replicas)
├── Envoy sidecar (gRPC transcoder)
├── NetworkPolicies (Calico)
├── HPA (auto-scaling)
└── PDB (disruption budget)
    │
    ▼ GCE Ingress + ManagedCertificate
Google Cloud Load Balancer
    │
    ▼ HTTPS
Clients
```

## Environments

| Env | GKE | Nodes | Image Tags | Trigger | Cost |
|-----|-----|-------|-----------|---------|------|
| Dev | Zonal (sae1-a) | 1x e2-medium | `dev-{sha}` | Push `develop` | ~$15/mo |
| Staging | Regional (sae1) | 2x e2-standard-2 | `staging-{sha}` | Push `staging` | ~$40/mo |
| Production | Regional (sae1) | 3x e2-standard-4 | `v*.*.*` | Manual + approval | ~$300/mo |

## Quick Start

### 1. Terraform (Infrastructure)
```bash
cd deployment/infra/gcp/environments/dev
terraform init
terraform plan -var="project_id=revenu-gateway-dev"
terraform apply
```

### 2. Helm (Application)
```bash
# Get GKE credentials
gcloud container clusters get-credentials gateway-dev-cluster --zone southamerica-east1-a

# Deploy
helm upgrade --install gateway k8s/helm/gateway \
  -f k8s/helm/gateway/values-gcp-dev.yaml \
  --set image.tag=dev-latest
```

### 3. Verify
```bash
kubectl get pods -l app.kubernetes.io/name=gateway
kubectl port-forward svc/gateway 8080:8080
curl http://localhost:8080/__health
```

## Prerequisites

- GCP project per environment
- Terraform state bucket: `revenu-terraform-state-gcp`
- GitHub secrets configured (per env):
  - `GCP_WORKLOAD_IDENTITY_PROVIDER_{ENV}`
  - `GCP_SERVICE_ACCOUNT_{ENV}`
  - `SLACK_WEBHOOK_URL`
