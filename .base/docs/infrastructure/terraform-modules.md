# Terraform Modules

Infrastructure-as-Code at `deployment/infra/gcp/modules/`.

## Module Inventory

| Module | Path | Purpose |
|--------|------|---------|
| vpc | `modules/vpc/` | VPC network, subnets, firewall rules |
| gke | `modules/gke/` | Google Kubernetes Engine cluster |
| artifact-registry | `modules/artifact-registry/` | Container image registry |
| kms | `modules/kms/` | Key Management Service |
| dns | `modules/dns/` | DNS zone and records |
| monitoring | `modules/monitoring/` | Cloud Monitoring and alerting |

## VPC Module

Creates the network infrastructure for GKE:
- VPC with custom subnets
- Firewall rules for internal communication
- NAT gateway for outbound internet access
- Region: `southamerica-east1`

## GKE Module

Provisions the Kubernetes cluster:
- Regional or zonal cluster (dev=zonal, staging/prod=regional)
- Node pools with autoscaling
- Workload Identity enabled
- Network policy enforcement
- Private cluster with authorized networks

## Artifact Registry Module

Container image storage:
- Repository per environment
- Dev: `southamerica-east1-docker.pkg.dev/revenu-gateway-dev/gateway-dev`
- Prod: `southamerica-east1-docker.pkg.dev/revenu-gateway-production/gateway-prod`
- Vulnerability scanning enabled

## KMS Module

Encryption key management:
- Customer-managed encryption keys (CMEK)
- Key rotation policies
- Used for GKE secrets encryption and container signing

## DNS Module

DNS configuration:
- Dev: `gateway.allenty.io`
- Prod: `api.revenu.com.br`
- Cloud DNS managed zones
- A/CNAME records for load balancer IPs

## Monitoring Module

Cloud Monitoring setup:
- Uptime checks
- Alert policies
- Notification channels
- Dashboard provisioning

## Shared Configuration

At `deployment/infra/gcp/shared/`:
- `providers.tf` — Google provider configuration
- `variables.tf` — Common variables (project_id, region, environment)
- `backend.tf` — Terraform state backend (GCS bucket)
