# =============================================================================
# Grafana Global Static IP — for GCE Ingress
# ISO 27001: A.8.20 (Network security)
# =============================================================================

resource "google_compute_global_address" "grafana" {
  name    = "grafana-${var.environment}-ip"
  project = var.project_id
}

output "grafana_ip" {
  value       = google_compute_global_address.grafana.address
  description = "Grafana global static IP — add as A record in Cloudflare"
}
