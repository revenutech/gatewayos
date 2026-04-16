# =============================================================================
# OTel Collector IAM — Workload Identity for GCP Cloud Logging & Trace
# ISO 27001: A.8.2 (Privileged access), A.12.4.1 (Event logging)
# =============================================================================

# --- GCP Service Account for OTel Collector ---
resource "google_service_account" "otel_collector" {
  account_id   = "otel-collector-${var.environment}"
  display_name = "OTel Collector SA (${var.environment})"
  project      = var.project_id
}

# --- IAM: Cloud Trace Agent ---
resource "google_project_iam_member" "trace_agent" {
  project = var.project_id
  role    = "roles/cloudtrace.agent"
  member  = "serviceAccount:${google_service_account.otel_collector.email}"
}

# --- IAM: Cloud Logging Writer ---
resource "google_project_iam_member" "log_writer" {
  project = var.project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.otel_collector.email}"
}

# --- IAM: Cloud Monitoring Metric Writer ---
resource "google_project_iam_member" "metric_writer" {
  project = var.project_id
  role    = "roles/monitoring.metricWriter"
  member  = "serviceAccount:${google_service_account.otel_collector.email}"
}

# --- Workload Identity Binding ---
resource "google_service_account_iam_member" "workload_identity" {
  service_account_id = google_service_account.otel_collector.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:${var.project_id}.svc.id.goog[monitoring/otel-collector]"
}

# --- Variables ---
variable "project_id" {
  type        = string
  description = "GCP project ID"
}

variable "environment" {
  type        = string
  description = "Environment name (dev, staging, production)"
}

# --- Outputs ---
output "service_account_email" {
  value       = google_service_account.otel_collector.email
  description = "OTel Collector GCP SA email for Workload Identity annotation"
}
