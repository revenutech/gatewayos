# =============================================================================
# Revenu Platform — Gateway GCP Staging Environment
# ISO 27001: A.8.31 (Separation of environments)
# Estimated cost: ~$40/month
# =============================================================================

variable "project_id" {
  type    = string
  default = "revenu-gateway-staging"
}

locals {
  environment = "staging"
  region      = "southamerica-east1"
  labels = {
    app         = "gateway"
    environment = "staging"
    managed-by  = "terraform"
    platform    = "revenu"
    iso27001    = "true"
  }
}

terraform {
  backend "gcs" {
    bucket = "revenu-platform-tf-state"
    prefix = "gateway/staging"
  }
}

# --- VPC ---
module "vpc" {
  source      = "../../modules/vpc"
  project_id  = var.project_id
  region      = local.region
  vpc_name    = "gateway-staging-vpc"
  subnet_cidr = "10.20.16.0/20"
  pods_cidr   = "10.23.0.0/16"
  services_cidr = "10.24.0.0/20"
}

# --- GKE ---
module "gke" {
  source        = "../../modules/gke"
  project_id    = var.project_id
  region        = local.region
  environment   = local.environment
  cluster_name  = "gateway-staging-cluster"
  regional      = true  # HA for staging
  network_id    = module.vpc.network_id
  subnet_id     = module.vpc.subnet_id
  node_count    = 2
  min_nodes     = 2
  max_nodes     = 4
  machine_type  = "e2-standard-2"
  release_channel = "REGULAR"
  binary_auth   = false
  labels        = local.labels

  master_authorized_cidrs = [
    { cidr = "0.0.0.0/0", name = "github-actions" }
  ]
}

# --- Artifact Registry ---
module "artifact_registry" {
  source          = "../../modules/artifact-registry"
  project_id      = var.project_id
  region          = local.region
  repository_name = "gateway-staging"
  keep_count      = 30
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

# --- DNS ---
module "dns" {
  source      = "../../modules/dns"
  project_id  = var.project_id
  environment = local.environment
  zone_name   = "gateway-staging-zone"
  domain      = "gateway-staging.revenu.com.br"
  labels      = local.labels
}

# --- Monitoring ---
module "monitoring" {
  source            = "../../modules/monitoring"
  project_id        = var.project_id
  environment       = local.environment
  alert_email       = "staging-alerts@revenu.com.br"
  slack_webhook_url = "" # Set via TF_VAR_slack_webhook_url
  labels            = local.labels
}

# --- Outputs ---
output "gke_cluster_name" { value = module.gke.cluster_name }
output "gke_cluster_endpoint" { value = module.gke.cluster_endpoint }
output "ar_repository_url" { value = module.artifact_registry.repository_url }
output "gateway_app_sa" { value = module.gke.gateway_app_sa_email }
output "gateway_ci_sa" { value = module.gke.gateway_ci_sa_email }
