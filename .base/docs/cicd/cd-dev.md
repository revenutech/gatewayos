# CD Dev Pipeline

File: `.github/workflows/cd-dev-gcp.yml`
Triggers: push to `develop`

## Steps

1. **Auth:** Workload Identity Federation (GCP_WORKLOAD_IDENTITY_PROVIDER_DEV)
2. **Configure Docker:** `gcloud auth configure-docker southamerica-east1-docker.pkg.dev`
3. **Build:** Docker image tagged `dev-{sha}` + `dev-latest`
4. **Push:** To Artifact Registry `southamerica-east1-docker.pkg.dev/revenu-gateway-dev/gateway-dev/gateway`
5. **Deploy:** Helm upgrade with `values-gcp-dev.yaml`, `--set image.tag=dev-{sha}`, `--wait 5m`
6. **Health check:** Poll pod status (15 attempts x 10s)

## Configuration

```yaml
env:
  GKE_CLUSTER: gateway-dev-cluster
  GKE_ZONE: southamerica-east1-a
  AR_REPO: southamerica-east1-docker.pkg.dev/revenu-gateway-dev/gateway-dev
  IMAGE_NAME: gateway
```

## Helm Deploy Command

```bash
helm upgrade --install gateway k8s/helm/gateway \
  -f k8s/helm/gateway/values-gcp-dev.yaml \
  --set image.tag=dev-${GITHUB_SHA} \
  --set configHash=${GITHUB_SHA} \
  --wait --timeout 5m
```
