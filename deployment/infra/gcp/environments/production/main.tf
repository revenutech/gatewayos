# =============================================================================
# Revenu Platform — Gateway GCP Production Environment
# ISO 27001: A.8.31 (Separation of environments), A.8.24 (Cryptography - HSM)
# Estimated cost: ~$300/month
# =============================================================================

variable "project_id" {
  type    = string
  default = "revenu-gateway-production"
}

locals {
  environment = "production"
  region      = "southamerica-east1"
  labels = {
    app         = "gateway"
    environment = "production"
    managed-by  = "terraform"
    platform    = "revenu"
    iso27001    = "true"
    bacen       = "compliant"
  }
}

terraform {
  backend "gcs" {
    bucket = "revenu-platform-tf-state"
    prefix = "gateway/production"
  }
}

# --- VPC ---
module "vpc" {
  source      = "../../modules/vpc"
  project_id  = var.project_id
  region      = local.region
  vpc_name    = "gateway-prod-vpc"
  subnet_cidr = "10.20.32.0/20"
  pods_cidr   = "10.25.0.0/16"
  services_cidr = "10.26.0.0/20"
}

# --- GKE ---
module "gke" {
  source        = "../../modules/gke"
  project_id    = var.project_id
  region        = local.region
  environment   = local.environment
  cluster_name  = "gateway-prod-cluster"
  regional      = true  # HA across 3 zones
  network_id    = module.vpc.network_id
  subnet_id     = module.vpc.subnet_id
  node_count    = 3
  min_nodes     = 3
  max_nodes     = 8
  machine_type  = "e2-standard-4"
  release_channel = "STABLE"
  binary_auth   = true  # Only signed images
  labels        = local.labels

  master_authorized_cidrs = [
    { cidr = "0.0.0.0/0", name = "github-actions" }
    # In production, restrict to CI/CD IP ranges
  ]
}

# --- Artifact Registry ---
module "artifact_registry" {
  source          = "../../modules/artifact-registry"
  project_id      = var.project_id
  region          = local.region
  repository_name = "gateway-prod"
  keep_count      = 50
  immutable_tags  = true  # Prevent image mutation
  ci_sa_email     = module.gke.gateway_ci_sa_email
  gke_sa_email    = module.gke.gateway_app_sa_email
  labels          = local.labels
}

# --- KMS (HSM for production) ---
module "kms" {
  source           = "../../modules/kms"
  project_id       = var.project_id
  region           = local.region
  environment      = local.environment
  protection_level = "HSM"  # FIPS 140-2 Level 3
  labels           = local.labels
}

# --- DNS ---
module "dns" {
  source      = "../../modules/dns"
  project_id  = var.project_id
  environment = local.environment
  zone_name   = "gateway-prod-zone"
  domain      = "api.revenu.com.br"
  labels      = local.labels
}

# --- Monitoring ---
module "monitoring" {
  source            = "../../modules/monitoring"
  project_id        = var.project_id
  environment       = local.environment
  alert_email       = "prod-alerts@revenu.com.br"
  slack_webhook_url = "" # Set via TF_VAR_slack_webhook_url
  labels            = local.labels
}

# --- OTel Collector (Cloud Logging + Trace) ---
module "otel_collector" {
  source      = "../../modules/otel-collector"
  project_id  = var.project_id
  environment = local.environment
}

# --- Outputs ---
output "gke_cluster_name" { value = module.gke.cluster_name }
output "gke_cluster_endpoint" { value = module.gke.cluster_endpoint }
output "ar_repository_url" { value = module.artifact_registry.repository_url }
output "gateway_app_sa" { value = module.gke.gateway_app_sa_email }
output "gateway_ci_sa" { value = module.gke.gateway_ci_sa_email }
output "otel_collector_sa" { value = module.otel_collector.service_account_email }
output "dashboard_url" { value = module.monitoring.dashboard_url }
