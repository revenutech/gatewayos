# =============================================================================
# Artifact Registry Module — Gateway
# ISO 27001: A.5.21 (ICT supply chain), A.8.19 (Software installation)
# =============================================================================

resource "google_artifact_registry_repository" "gateway" {
  location      = var.region
  repository_id = var.repository_name
  format        = "DOCKER"
  project       = var.project_id

  docker_config {
    immutable_tags = var.immutable_tags
  }

  cleanup_policies {
    id     = "keep-tagged"
    action = "KEEP"

    most_recent_versions {
      keep_count = var.keep_count
    }
  }

  cleanup_policies {
    id     = "delete-untagged"
    action = "DELETE"

    condition {
      tag_state  = "UNTAGGED"
      older_than = "604800s" # 7 days
    }
  }

  labels = var.labels
}

resource "google_artifact_registry_repository_iam_member" "ci_writer" {
  project    = var.project_id
  location   = var.region
  repository = google_artifact_registry_repository.gateway.name
  role       = "roles/artifactregistry.writer"
  member     = "serviceAccount:${var.ci_sa_email}"
}

resource "google_artifact_registry_repository_iam_member" "gke_reader" {
  project    = var.project_id
  location   = var.region
  repository = google_artifact_registry_repository.gateway.name
  role       = "roles/artifactregistry.reader"
  member     = "serviceAccount:${var.gke_sa_email}"
}

variable "project_id" { type = string }
variable "region" { type = string }
variable "repository_name" { type = string }
variable "immutable_tags" { type = bool; default = false }
variable "keep_count" { type = number; default = 10 }
variable "ci_sa_email" { type = string }
variable "gke_sa_email" { type = string }
variable "labels" { type = map(string); default = {} }

output "repository_url" {
  value = "${var.region}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.gateway.name}"
}
