# Helm Chart

Chart at `k8s/helm/gateway/`.

## Structure

```
k8s/helm/gateway/
  Chart.yaml                    # Chart metadata
  values.yaml                   # Default values
  values-gcp-dev.yaml           # GCP dev overrides
  values-gcp-staging.yaml       # GCP staging overrides
  values-gcp-production.yaml    # GCP production overrides
  templates/
    deployment.yaml             # KrakenD + Envoy sidecar
    service.yaml                # ClusterIP service
    ingress.yaml                # Ingress with TLS
    serviceaccount.yaml         # ServiceAccount + RBAC
    hpa.yaml                    # HorizontalPodAutoscaler
    pdb.yaml                    # PodDisruptionBudget
    servicemonitor.yaml         # Prometheus ServiceMonitor
    networkpolicy.yaml          # Network policies
    backend-config.yaml         # GCP BackendConfig (health checks, CDN)
    managed-certificate.yaml    # GCP ManagedCertificate (auto TLS)
```

## Deployment Commands

### Install/Upgrade

```bash
# Dev
helm upgrade --install gateway k8s/helm/gateway \
  -f k8s/helm/gateway/values-gcp-dev.yaml \
  --set image.tag=dev-${SHA} \
  --wait --timeout 5m

# Production (atomic — auto-rollback on failure)
helm upgrade --install gateway k8s/helm/gateway \
  -f k8s/helm/gateway/values-gcp-production.yaml \
  --set image.tag=${TAG} \
  --atomic --wait --timeout 5m
```

### Rollback

```bash
helm rollback gateway 0  # Roll back to previous release
```

### Status

```bash
helm status gateway
helm history gateway
```

## GCP-Specific Templates

### backend-config.yaml

GCP BackendConfig for GCE Ingress:
- Health check configuration
- Connection draining timeout
- CDN/Cloud Armor policies

### managed-certificate.yaml

GCP ManagedCertificate for automatic TLS certificate provisioning via Google-managed SSL certificates.
