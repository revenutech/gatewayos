# =============================================================================
# GKE Module — Gateway
# ISO 27001: A.8.2 (Privileged access), A.8.14 (Redundancy), A.8.22 (Network segregation)
# =============================================================================

# --- GKE Node Service Account (minimal permissions) ---
resource "google_service_account" "gke_nodes" {
  account_id   = "${var.cluster_name}-nodes"
  display_name = "GKE Nodes SA for ${var.cluster_name}"
  project      = var.project_id
}

resource "google_project_iam_member" "gke_log_writer" {
  project = var.project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.gke_nodes.email}"
}

resource "google_project_iam_member" "gke_metric_writer" {
  project = var.project_id
  role    = "roles/monitoring.metricWriter"
  member  = "serviceAccount:${google_service_account.gke_nodes.email}"
}

resource "google_project_iam_member" "gke_ar_reader" {
  project = var.project_id
  role    = "roles/artifactregistry.reader"
  member  = "serviceAccount:${google_service_account.gke_nodes.email}"
}

# --- GKE Cluster ---
resource "google_container_cluster" "cluster" {
  provider = google-beta

  name     = var.cluster_name
  location = var.regional ? var.region : var.zone
  project  = var.project_id

  remove_default_node_pool = true
  initial_node_count       = 1

  network    = var.network_id
  subnetwork = var.subnet_id

  ip_allocation_policy {
    cluster_secondary_range_name  = "gke-pods"
    services_secondary_range_name = "gke-services"
  }

  release_channel {
    channel = var.release_channel
  }

  workload_identity_config {
    workload_pool = "${var.project_id}.svc.id.goog"
  }

  network_policy {
    enabled  = true
    provider = "CALICO"
  }

  private_cluster_config {
    enable_private_nodes    = true
    enable_private_endpoint = false
    master_ipv4_cidr_block  = "172.16.0.0/28"
  }

  master_authorized_networks_config {
    dynamic "cidr_blocks" {
      for_each = var.master_authorized_cidrs
      content {
        cidr_block   = cidr_blocks.value.cidr
        display_name = cidr_blocks.value.name
      }
    }
  }

  dynamic "binary_authorization" {
    for_each = var.binary_auth ? [1] : []
    content {
      evaluation_mode = "PROJECT_SINGLETON_POLICY_ENFORCE"
    }
  }

  node_config {
    shielded_instance_config {
      enable_secure_boot          = true
      enable_integrity_monitoring = true
    }
  }

  logging_service    = "logging.googleapis.com/kubernetes"
  monitoring_service = "monitoring.googleapis.com/kubernetes"

  resource_labels = var.labels
}

# --- Node Pool ---
resource "google_container_node_pool" "app_pool" {
  name     = "${var.cluster_name}-app-pool"
  location = var.regional ? var.region : var.zone
  cluster  = google_container_cluster.cluster.name
  project  = var.project_id

  initial_node_count = var.node_count

  autoscaling {
    min_node_count = var.min_nodes
    max_node_count = var.max_nodes
  }

  management {
    auto_repair  = true
    auto_upgrade = true
  }

  node_config {
    machine_type    = var.machine_type
    service_account = google_service_account.gke_nodes.email
    oauth_scopes    = ["https://www.googleapis.com/auth/cloud-platform"]

    labels = merge(var.labels, {
      "nodepool" = "app"
    })

    shielded_instance_config {
      enable_secure_boot          = true
      enable_integrity_monitoring = true
    }

    workload_metadata_config {
      mode = "GKE_METADATA"
    }
  }
}

# --- Workload Identity SA (for gateway pods) ---
resource "google_service_account" "gateway_app" {
  account_id   = "gateway-app-${var.environment}"
  display_name = "Gateway App SA (${var.environment})"
  project      = var.project_id
}

resource "google_service_account_iam_member" "workload_identity" {
  service_account_id = google_service_account.gateway_app.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:${var.project_id}.svc.id.goog[default/gateway]"
}

# --- CI/CD SA ---
resource "google_service_account" "gateway_ci" {
  account_id   = "gateway-ci-${var.environment}"
  display_name = "Gateway CI/CD SA (${var.environment})"
  project      = var.project_id
}

resource "google_project_iam_member" "ci_ar_writer" {
  project = var.project_id
  role    = "roles/artifactregistry.writer"
  member  = "serviceAccount:${google_service_account.gateway_ci.email}"
}

resource "google_project_iam_member" "ci_gke_developer" {
  project = var.project_id
  role    = "roles/container.developer"
  member  = "serviceAccount:${google_service_account.gateway_ci.email}"
}

variable "project_id" { type = string }
variable "region" { type = string }
variable "zone" { type = string; default = "southamerica-east1-a" }
variable "environment" { type = string }
variable "cluster_name" { type = string }
variable "regional" { type = bool; default = false }
variable "network_id" { type = string }
variable "subnet_id" { type = string }
variable "node_count" { type = number; default = 1 }
variable "min_nodes" { type = number; default = 1 }
variable "max_nodes" { type = number; default = 3 }
variable "machine_type" { type = string; default = "e2-medium" }
variable "release_channel" { type = string; default = "REGULAR" }
variable "binary_auth" { type = bool; default = false }
variable "labels" { type = map(string); default = {} }
variable "master_authorized_cidrs" {
  type = list(object({ cidr = string, name = string }))
  default = [{ cidr = "0.0.0.0/0", name = "all" }]
}

output "cluster_name" { value = google_container_cluster.cluster.name }
output "cluster_endpoint" { value = google_container_cluster.cluster.endpoint }
output "cluster_ca_certificate" { value = google_container_cluster.cluster.master_auth[0].cluster_ca_certificate }
output "gateway_app_sa_email" { value = google_service_account.gateway_app.email }
output "gateway_ci_sa_email" { value = google_service_account.gateway_ci.email }
