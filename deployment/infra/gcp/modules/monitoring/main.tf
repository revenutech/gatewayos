# =============================================================================
# Monitoring Module — Gateway
# ISO 27001: A.8.16 (Monitoring activities), A.5.25 (Assessment of events)
# =============================================================================

resource "google_monitoring_notification_channel" "email" {
  display_name = "Gateway Alerts Email (${var.environment})"
  type         = "email"
  project      = var.project_id

  labels = {
    email_address = var.alert_email
  }
}

resource "google_monitoring_notification_channel" "slack" {
  count = var.slack_webhook_url != "" ? 1 : 0

  display_name = "Gateway Alerts Slack (${var.environment})"
  type         = "slack"
  project      = var.project_id

  labels = {
    channel_name = "#gateway-alerts"
  }

  sensitive_labels {
    auth_token = var.slack_webhook_url
  }
}

locals {
  notification_channels = concat(
    [google_monitoring_notification_channel.email.name],
    var.slack_webhook_url != "" ? [google_monitoring_notification_channel.slack[0].name] : []
  )
}

# Alert: High 5xx error rate
resource "google_monitoring_alert_policy" "high_error_rate" {
  display_name = "Gateway High Error Rate (${var.environment})"
  project      = var.project_id
  combiner     = "OR"

  conditions {
    display_name = "5xx rate > 5%"
    condition_threshold {
      filter          = "resource.type = \"k8s_container\" AND resource.labels.container_name = \"krakend\" AND metric.type = \"logging.googleapis.com/log_entry_count\" AND metric.labels.severity = \"ERROR\""
      comparison      = "COMPARISON_GT"
      threshold_value = 10
      duration        = "300s"

      aggregations {
        alignment_period   = "60s"
        per_series_aligner = "ALIGN_RATE"
      }
    }
  }

  notification_channels = local.notification_channels

  alert_strategy {
    auto_close = "1800s"
  }

  user_labels = var.labels
}

# Alert: Pod restarts
resource "google_monitoring_alert_policy" "pod_restarts" {
  display_name = "Gateway Pod Restarts (${var.environment})"
  project      = var.project_id
  combiner     = "OR"

  conditions {
    display_name = "Pod restarts > 3 in 10min"
    condition_threshold {
      filter          = "resource.type = \"k8s_container\" AND resource.labels.container_name = \"krakend\" AND metric.type = \"kubernetes.io/container/restart_count\""
      comparison      = "COMPARISON_GT"
      threshold_value = 3
      duration        = "600s"

      aggregations {
        alignment_period   = "60s"
        per_series_aligner = "ALIGN_DELTA"
      }
    }
  }

  notification_channels = local.notification_channels
  user_labels           = var.labels
}

variable "project_id" {
  type = string
}
variable "environment" {
  type = string
}
variable "alert_email" {
  type = string
}
variable "slack_webhook_url" {
  type = string
  default = ""
  sensitive = true
}
variable "labels" {
  type    = map(string)
  default = {}
}
