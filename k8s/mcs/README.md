# Multi-Cluster Services (MCS) for Gateway

This directory contains ServiceImport manifests for accessing services in other GKE clusters via MCS.

## How MCS Works

1. **ServiceExport** is created in the source cluster (e.g., keycloak-sqa)
2. **ServiceImport** is created in consuming clusters (e.g., gateway-sqa)
3. DNS resolution: `<service>.<namespace>.svc.clusterset.local`

## Keycloak ServiceImport

The `keycloak-service-import.yaml` enables gateway-sqa to access Keycloak in keycloak-sqa:

```
DNS: keycloak.keycloak.svc.clusterset.local:8080
```

### Apply

```bash
kubectl apply -f k8s/mcs/keycloak-service-import.yaml --context gke_revenu-gateway-sqa_southamerica-east1-a_gateway-sqa
```

### Verify

```bash
# Check ServiceImport
kubectl get serviceimport -n keycloak

# Test DNS resolution
kubectl run test --rm -it --restart=Never --image=busybox -- nslookup keycloak.keycloak.svc.clusterset.local

# Test connectivity
kubectl run test --rm -it --restart=Never --image=curlimages/curl -- curl -s http://keycloak.keycloak.svc.clusterset.local:8080/auth/realms/master/.well-known/openid-configuration
```

## Prerequisites

- Clusters must be in the same GKE Fleet
- MCS feature must be enabled (`gcloud container fleet multi-cluster-services enable`)
- Traffic Director API must be enabled
- Proper IAM permissions for MCS service account on Shared VPC
