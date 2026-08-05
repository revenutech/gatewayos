# =============================================================================
# Cloud DNS Module — Gateway
# ISO 27001: A.8.20 (Networks security)
# =============================================================================

resource "google_dns_managed_zone" "gateway" {
  count = var.zone_name != "" ? 1 : 0

  name        = var.zone_name
  dns_name    = "${var.domain}."
  project     = var.project_id
  description = "DNS zone for Gateway ${var.environment}"

  dnssec_config {
    state = "on"
  }

  labels = var.labels
}

resource "google_dns_record_set" "gateway_a" {
  count = var.zone_name != "" && var.ingress_ip != "" ? 1 : 0

  name         = "${var.domain}."
  managed_zone = google_dns_managed_zone.gateway[0].name
  type         = "A"
  ttl          = 300
  rrdatas      = [var.ingress_ip]
  project      = var.project_id
}

variable "project_id" {
  type = string
}
variable "environment" {
  type = string
}
variable "zone_name" {
  type    = string
  default = ""
}
variable "domain" {
  type    = string
  default = ""
}
variable "ingress_ip" {
  type    = string
  default = ""
}
variable "labels" {
  type    = map(string)
  default = {}
}

output "zone_name" {
  description = "Managed zone name (empty when the zone is not created)"
  value       = try(google_dns_managed_zone.gateway[0].name, "")
}

output "nameservers" {
  description = "Zone name servers, for delegation at the registrar"
  value       = try(google_dns_managed_zone.gateway[0].name_servers, [])
}
