# =============================================================================
# Revenu Platform — Gateway GCP Dev Environment
# ISO 27001: A.8.31 (Separation of environments)
# Estimated cost: ~$15/month
# =============================================================================

variable "project_id" {
  type    = string
  default = "revenu-gateway-dev"
}

locals {
  environment = "dev"
  region      = "southamerica-east1"
  labels = {
    app         = "gateway"
    environment = "dev"
    managed-by  = "terraform"
    platform    = "revenu"
    iso27001    = "true"
  }
}

terraform {
  backend "gcs" {
    bucket = "revenu-platform-tf-state"
    prefix = "gateway/dev"
  }
}

# --- VPC ---
module "vpc" {
  source      = "../../modules/vpc"
  project_id  = var.project_id
  region      = local.region
  vpc_name    = "gateway-dev-vpc"
  subnet_cidr = "10.20.0.0/20"
  pods_cidr   = "10.21.0.0/16"
  services_cidr = "10.22.0.0/20"
}

# --- GKE ---
module "gke" {
  source        = "../../modules/gke"
  project_id    = var.project_id
  region        = local.region
  zone          = "southamerica-east1-a"
  environment   = local.environment
  cluster_name  = "gateway-dev-cluster"
  regional      = false  # zonal for cost savings
  network_id    = module.vpc.network_id
  subnet_id     = module.vpc.subnet_id
  node_count    = 1
  min_nodes     = 1
  max_nodes     = 2
  machine_type  = "e2-medium"
  release_channel = "REGULAR"
  binary_auth   = false
  labels        = local.labels

  master_authorized_cidrs = [
    { cidr = "0.0.0.0/0", name = "all-dev" }
  ]
}

# --- Artifact Registry ---
module "artifact_registry" {
  source          = "../../modules/artifact-registry"
  project_id      = var.project_id
  region          = local.region
  repository_name = "gateway-dev"
  keep_count      = 10
  immutable_tags  = false
  ci_sa_email     = module.gke.gateway_ci_sa_email
  gke_sa_email    = module.gke.gateway_app_sa_email
  labels          = local.labels
}

# --- KMS ---
module "kms" {
  source           = "../../modules/kms"
  project_id       = var.project_id
  region           = local.region
  environment      = local.environment
  protection_level = "SOFTWARE"
  labels           = local.labels
}

# --- Monitoring ---
module "monitoring" {
  source      = "../../modules/monitoring"
  project_id  = var.project_id
  environment = local.environment
  alert_email = "dev-alerts@revenu.com.br"
  labels      = local.labels
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
