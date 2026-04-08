# Terraform Environments

Three environments at `deployment/infra/gcp/environments/`.

## Environment Comparison

| Setting | Dev | Staging | Production |
|---------|-----|---------|------------|
| GKE Type | Zonal | Regional | Regional |
| GKE Zone/Region | southamerica-east1-a | southamerica-east1 | southamerica-east1 |
| Cluster Name | gateway-dev-cluster | gateway-staging-cluster | gateway-prod-cluster |
| GCP Project | revenu-gateway-dev | revenu-gateway-staging | revenu-gateway-production |
| AR Repo | gateway-dev | gateway-staging | gateway-prod |

## Usage

### Plan

```bash
cd deployment/infra/gcp/environments/dev
terraform init
terraform plan
```

### Apply

```bash
terraform apply
```

### State Management

Terraform state is stored in GCS buckets (configured in `shared/backend.tf`):
- Dev: `gs://revenu-gateway-dev-tfstate/`
- Staging: `gs://revenu-gateway-staging-tfstate/`
- Production: `gs://revenu-gateway-production-tfstate/`

State locking via GCS object versioning.

## Environment Promotion

Infrastructure changes should be applied in order: dev → staging → production. Test in dev, validate in staging, apply to production with approval.
