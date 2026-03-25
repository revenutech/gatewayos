# =============================================================================
# Revenu Platform — Gateway Terraform Shared Variables
# =============================================================================

variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "region" {
  description = "GCP region"
  type        = string
  default     = "southamerica-east1"
}

variable "environment" {
  description = "Environment name (dev, staging, production)"
  type        = string
  validation {
    condition     = contains(["dev", "staging", "production"], var.environment)
    error_message = "Environment must be dev, staging, or production."
  }
}

# --- VPC ---
variable "vpc_name" {
  description = "VPC network name"
  type        = string
}

variable "subnet_cidr" {
  description = "Primary subnet CIDR"
  type        = string
}

variable "pods_cidr" {
  description = "Secondary range for GKE pods"
  type        = string
  default     = "10.1.0.0/16"
}

variable "services_cidr" {
  description = "Secondary range for GKE services"
  type        = string
  default     = "10.2.0.0/20"
}

# --- GKE ---
variable "gke_cluster_name" {
  description = "GKE cluster name"
  type        = string
}

variable "gke_regional" {
  description = "Use regional cluster (HA) vs zonal"
  type        = bool
  default     = false
}

variable "gke_zone" {
  description = "GKE zone (for zonal clusters)"
  type        = string
  default     = "southamerica-east1-a"
}

variable "gke_node_count" {
  description = "Initial node count per zone"
  type        = number
  default     = 1
}

variable "gke_min_nodes" {
  description = "Min nodes for autoscaling"
  type        = number
  default     = 1
}

variable "gke_max_nodes" {
  description = "Max nodes for autoscaling"
  type        = number
  default     = 3
}

variable "gke_machine_type" {
  description = "GKE node machine type"
  type        = string
  default     = "e2-medium"
}

variable "gke_release_channel" {
  description = "GKE release channel"
  type        = string
  default     = "REGULAR"
}

variable "gke_binary_auth" {
  description = "Enable Binary Authorization"
  type        = bool
  default     = false
}

# --- Artifact Registry ---
variable "ar_repository_name" {
  description = "Artifact Registry repository name"
  type        = string
}

variable "ar_keep_count" {
  description = "Number of tagged images to keep"
  type        = number
  default     = 10
}

variable "ar_immutable_tags" {
  description = "Enable immutable tags"
  type        = bool
  default     = false
}

# --- KMS ---
variable "kms_protection_level" {
  description = "KMS key protection level (SOFTWARE or HSM)"
  type        = string
  default     = "SOFTWARE"
}

# --- DNS ---
variable "dns_zone_name" {
  description = "Cloud DNS zone name"
  type        = string
  default     = ""
}

variable "dns_domain" {
  description = "DNS domain for the gateway"
  type        = string
  default     = ""
}

# --- Monitoring ---
variable "alert_email" {
  description = "Email for alert notifications"
  type        = string
  default     = "alerts@revenu.com.br"
}

variable "slack_webhook_url" {
  description = "Slack webhook for alert notifications"
  type        = string
  default     = ""
  sensitive   = true
}

# --- Labels ---
variable "labels" {
  description = "Common labels for all resources"
  type        = map(string)
  default = {
    "app"         = "gateway"
    "managed-by"  = "terraform"
    "platform"    = "revenu"
    "iso27001"    = "true"
  }
}
