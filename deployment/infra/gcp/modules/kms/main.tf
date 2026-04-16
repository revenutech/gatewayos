# =============================================================================
# Cloud KMS Module — Gateway
# ISO 27001: A.8.24 (Cryptography), A.10.1.1 (Cryptographic controls)
# =============================================================================

resource "google_kms_key_ring" "gateway" {
  name     = "gateway-${var.environment}"
  location = var.region
  project  = var.project_id
}

resource "google_kms_crypto_key" "gateway" {
  name            = "gateway-key"
  key_ring        = google_kms_key_ring.gateway.id
  rotation_period = "7776000s" # 90 days
  purpose         = "ENCRYPT_DECRYPT"

  version_template {
    algorithm        = "GOOGLE_SYMMETRIC_ENCRYPTION"
    protection_level = var.protection_level
  }

  labels = var.labels
}

variable "project_id" {
  type = string
}
variable "region" {
  type = string
}
variable "environment" {
  type = string
}
variable "protection_level" {
  type = string
  default = "SOFTWARE"
}
variable "labels" {
  type = map(string)
  default = {}
}

output "key_ring_id" { value = google_kms_key_ring.gateway.id }
