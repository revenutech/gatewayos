# =============================================================================
# Grafana IAM — Workload Identity for Cloud Monitoring read access
# ISO 27001: A.8.2 (Privileged access), A.8.16 (Monitoring activities)
# =============================================================================

resource "google_service_account" "grafana" {
  account_id   = "grafana-${var.environment}"
  display_name = "Grafana SA (${var.environment})"
  project      = var.project_id
}

# Read-only access to Cloud Monitoring metrics
resource "google_project_iam_member" "grafana_monitoring_viewer" {
  project = var.project_id
  role    = "roles/monitoring.viewer"
  member  = "serviceAccount:${google_service_account.grafana.email}"
}

# Read-only access to Cloud Logging (for log-based metrics)
resource "google_project_iam_member" "grafana_logging_viewer" {
  project = var.project_id
  role    = "roles/logging.viewer"
  member  = "serviceAccount:${google_service_account.grafana.email}"
}

# Read-only access to Cloud Trace
resource "google_project_iam_member" "grafana_trace_viewer" {
  project = var.project_id
  role    = "roles/cloudtrace.user"
  member  = "serviceAccount:${google_service_account.grafana.email}"
}

# Workload Identity binding
resource "google_service_account_iam_member" "grafana_workload_identity" {
  service_account_id = google_service_account.grafana.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:${var.project_id}.svc.id.goog[monitoring/grafana]"
}

output "grafana_sa_email" {
  value       = google_service_account.grafana.email
  description = "Grafana GCP SA email for Workload Identity annotation"
}
