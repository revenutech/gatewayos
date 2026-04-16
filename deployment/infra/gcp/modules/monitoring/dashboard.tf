# =============================================================================
# Cloud Monitoring Dashboard — Gateway
# ISO 27001: A.8.16 (Monitoring activities), A.8.6 (Capacity management)
#
# Sections:
#   1. Overview (request rate, error rate, latency P50/P95/P99)
#   2. Backend Health (circuit breakers, backend latency per service)
#   3. Security (auth failures, blocked requests, JWE guard hits)
#   4. Infrastructure (CPU, memory, pod restarts, OTel collector)
# =============================================================================

resource "google_monitoring_dashboard" "gateway" {
  dashboard_json = jsonencode({
    displayName = "Revenu Gateway — ${var.environment}"

    mosaicLayout = {
      columns = 12
      tiles = concat(
        # =====================================================================
        # Section 1: Overview
        # =====================================================================
        [
          {
            width  = 12
            height = 1
            widget = {
              title = ""
              text = {
                content = "## Overview"
                format  = "MARKDOWN"
              }
            }
          },
          {
            yPos   = 1
            width  = 4
            height = 4
            widget = {
              title = "Request Rate (req/s)"
              xyChart = {
                dataSets = [{
                  timeSeriesQuery = {
                    timeSeriesFilter = {
                      filter = "resource.type = \"k8s_container\" AND resource.labels.container_name = \"krakend\" AND metric.type = \"custom.googleapis.com/opencensus/krakend/router/response/count\""
                      aggregation = {
                        alignmentPeriod  = "60s"
                        perSeriesAligner = "ALIGN_RATE"
                      }
                    }
                  }
                  plotType   = "LINE"
                  legendTemplate = "Requests"
                }]
                yAxis = { scale = "LINEAR" }
              }
            }
          },
          {
            xPos   = 4
            yPos   = 1
            width  = 4
            height = 4
            widget = {
              title = "Error Rate (5xx)"
              xyChart = {
                dataSets = [{
                  timeSeriesQuery = {
                    timeSeriesFilter = {
                      filter = "resource.type = \"k8s_container\" AND resource.labels.container_name = \"krakend\" AND metric.type = \"logging.googleapis.com/log_entry_count\" AND metric.labels.severity >= \"ERROR\""
                      aggregation = {
                        alignmentPeriod  = "60s"
                        perSeriesAligner = "ALIGN_RATE"
                      }
                    }
                  }
                  plotType   = "LINE"
                  legendTemplate = "5xx errors"
                }]
                yAxis = { scale = "LINEAR" }
                thresholds = [{
                  value     = 5
                  color     = "RED"
                  direction = "ABOVE"
                }]
              }
            }
          },
          {
            xPos   = 8
            yPos   = 1
            width  = 4
            height = 4
            widget = {
              title = "Latency P50 / P95 / P99 (ms)"
              xyChart = {
                dataSets = [
                  {
                    timeSeriesQuery = {
                      timeSeriesFilter = {
                        filter = "resource.type = \"k8s_container\" AND resource.labels.container_name = \"krakend\" AND metric.type = \"custom.googleapis.com/opencensus/krakend/router/response/latency\""
                        aggregation = {
                          alignmentPeriod    = "60s"
                          perSeriesAligner   = "ALIGN_PERCENTILE_50"
                        }
                      }
                    }
                    plotType       = "LINE"
                    legendTemplate = "P50"
                  },
                  {
                    timeSeriesQuery = {
                      timeSeriesFilter = {
                        filter = "resource.type = \"k8s_container\" AND resource.labels.container_name = \"krakend\" AND metric.type = \"custom.googleapis.com/opencensus/krakend/router/response/latency\""
                        aggregation = {
                          alignmentPeriod    = "60s"
                          perSeriesAligner   = "ALIGN_PERCENTILE_95"
                        }
                      }
                    }
                    plotType       = "LINE"
                    legendTemplate = "P95"
                  },
                  {
                    timeSeriesQuery = {
                      timeSeriesFilter = {
                        filter = "resource.type = \"k8s_container\" AND resource.labels.container_name = \"krakend\" AND metric.type = \"custom.googleapis.com/opencensus/krakend/router/response/latency\""
                        aggregation = {
                          alignmentPeriod    = "60s"
                          perSeriesAligner   = "ALIGN_PERCENTILE_99"
                        }
                      }
                    }
                    plotType       = "LINE"
                    legendTemplate = "P99"
                  }
                ]
                yAxis = { scale = "LINEAR" }
              }
            }
          }
        ],

        # =====================================================================
        # Section 2: Backend Health
        # =====================================================================
        [
          {
            yPos   = 5
            width  = 12
            height = 1
            widget = {
              title = ""
              text = {
                content = "## Backend Health"
                format  = "MARKDOWN"
              }
            }
          },
          {
            yPos   = 6
            width  = 6
            height = 4
            widget = {
              title = "Backend Latency by Service (ms)"
              xyChart = {
                dataSets = [{
                  timeSeriesQuery = {
                    timeSeriesFilter = {
                      filter = "resource.type = \"k8s_container\" AND resource.labels.container_name = \"krakend\" AND metric.type = \"custom.googleapis.com/opencensus/krakend/backend/response/latency\""
                      aggregation = {
                        alignmentPeriod    = "60s"
                        perSeriesAligner   = "ALIGN_PERCENTILE_95"
                        crossSeriesReducer = "REDUCE_MEAN"
                        groupByFields      = ["metric.labels.backend"]
                      }
                    }
                  }
                  plotType       = "LINE"
                  legendTemplate = "$${metric.labels.backend}"
                }]
                yAxis = { scale = "LINEAR" }
              }
            }
          },
          {
            xPos   = 6
            yPos   = 6
            width  = 6
            height = 4
            widget = {
              title = "Backend Error Rate by Service"
              xyChart = {
                dataSets = [{
                  timeSeriesQuery = {
                    timeSeriesFilter = {
                      filter = "resource.type = \"k8s_container\" AND resource.labels.container_name = \"krakend\" AND metric.type = \"custom.googleapis.com/opencensus/krakend/backend/response/error\""
                      aggregation = {
                        alignmentPeriod    = "60s"
                        perSeriesAligner   = "ALIGN_RATE"
                        crossSeriesReducer = "REDUCE_SUM"
                        groupByFields      = ["metric.labels.backend"]
                      }
                    }
                  }
                  plotType       = "STACKED_BAR"
                  legendTemplate = "$${metric.labels.backend}"
                }]
                yAxis = { scale = "LINEAR" }
              }
            }
          }
        ],

        # =====================================================================
        # Section 3: Security
        # =====================================================================
        [
          {
            yPos   = 10
            width  = 12
            height = 1
            widget = {
              title = ""
              text = {
                content = "## Security"
                format  = "MARKDOWN"
              }
            }
          },
          {
            yPos   = 11
            width  = 4
            height = 4
            widget = {
              title = "Auth Failures (401/403)"
              xyChart = {
                dataSets = [{
                  timeSeriesQuery = {
                    timeSeriesFilter = {
                      filter = "resource.type = \"k8s_container\" AND resource.labels.container_name = \"krakend\" AND metric.type = \"logging.googleapis.com/log_entry_count\" AND metric.labels.severity = \"WARNING\""
                      aggregation = {
                        alignmentPeriod  = "60s"
                        perSeriesAligner = "ALIGN_RATE"
                      }
                    }
                  }
                  plotType       = "LINE"
                  legendTemplate = "Auth failures"
                }]
                yAxis = { scale = "LINEAR" }
                thresholds = [{
                  value     = 50
                  color     = "YELLOW"
                  direction = "ABOVE"
                }]
              }
            }
          },
          {
            xPos   = 4
            yPos   = 11
            width  = 4
            height = 4
            widget = {
              title = "Rate Limited Requests (429)"
              xyChart = {
                dataSets = [{
                  timeSeriesQuery = {
                    timeSeriesFilter = {
                      filter = "resource.type = \"k8s_container\" AND resource.labels.container_name = \"krakend\" AND metric.type = \"logging.googleapis.com/log_entry_count\""
                      aggregation = {
                        alignmentPeriod  = "60s"
                        perSeriesAligner = "ALIGN_RATE"
                      }
                    }
                  }
                  plotType       = "LINE"
                  legendTemplate = "Rate limited"
                }]
                yAxis = { scale = "LINEAR" }
              }
            }
          },
          {
            xPos   = 8
            yPos   = 11
            width  = 4
            height = 4
            widget = {
              title = "Blocked Requests (Security Policies)"
              scorecard = {
                timeSeriesQuery = {
                  timeSeriesFilter = {
                    filter = "resource.type = \"k8s_container\" AND resource.labels.container_name = \"krakend\" AND metric.type = \"logging.googleapis.com/user/security_blocked\""
                    aggregation = {
                      alignmentPeriod  = "3600s"
                      perSeriesAligner = "ALIGN_SUM"
                    }
                  }
                }
                thresholds = [{
                  value     = 100
                  color     = "RED"
                  direction = "ABOVE"
                }]
              }
            }
          }
        ],

        # =====================================================================
        # Section 4: Infrastructure
        # =====================================================================
        [
          {
            yPos   = 15
            width  = 12
            height = 1
            widget = {
              title = ""
              text = {
                content = "## Infrastructure"
                format  = "MARKDOWN"
              }
            }
          },
          {
            yPos   = 16
            width  = 3
            height = 4
            widget = {
              title = "CPU Usage"
              xyChart = {
                dataSets = [{
                  timeSeriesQuery = {
                    timeSeriesFilter = {
                      filter = "resource.type = \"k8s_container\" AND resource.labels.container_name = \"krakend\" AND metric.type = \"kubernetes.io/container/cpu/core_usage_time\""
                      aggregation = {
                        alignmentPeriod    = "60s"
                        perSeriesAligner   = "ALIGN_RATE"
                        crossSeriesReducer = "REDUCE_MEAN"
                      }
                    }
                  }
                  plotType       = "LINE"
                  legendTemplate = "CPU cores"
                }]
                yAxis = { scale = "LINEAR" }
              }
            }
          },
          {
            xPos   = 3
            yPos   = 16
            width  = 3
            height = 4
            widget = {
              title = "Memory Usage (MB)"
              xyChart = {
                dataSets = [{
                  timeSeriesQuery = {
                    timeSeriesFilter = {
                      filter = "resource.type = \"k8s_container\" AND resource.labels.container_name = \"krakend\" AND metric.type = \"kubernetes.io/container/memory/used_bytes\""
                      aggregation = {
                        alignmentPeriod    = "60s"
                        perSeriesAligner   = "ALIGN_MEAN"
                        crossSeriesReducer = "REDUCE_MEAN"
                      }
                    }
                  }
                  plotType       = "LINE"
                  legendTemplate = "Memory"
                }]
                yAxis = { scale = "LINEAR" }
              }
            }
          },
          {
            xPos   = 6
            yPos   = 16
            width  = 3
            height = 4
            widget = {
              title = "Pod Restarts"
              xyChart = {
                dataSets = [{
                  timeSeriesQuery = {
                    timeSeriesFilter = {
                      filter = "resource.type = \"k8s_container\" AND resource.labels.container_name = \"krakend\" AND metric.type = \"kubernetes.io/container/restart_count\""
                      aggregation = {
                        alignmentPeriod  = "300s"
                        perSeriesAligner = "ALIGN_DELTA"
                      }
                    }
                  }
                  plotType       = "STACKED_BAR"
                  legendTemplate = "Restarts"
                }]
                yAxis = { scale = "LINEAR" }
              }
            }
          },
          {
            xPos   = 9
            yPos   = 16
            width  = 3
            height = 4
            widget = {
              title = "OTel Collector — Exported Spans"
              xyChart = {
                dataSets = [{
                  timeSeriesQuery = {
                    timeSeriesFilter = {
                      filter = "resource.type = \"k8s_container\" AND resource.labels.container_name = \"otel-collector\" AND metric.type = \"custom.googleapis.com/opencensus/otel_collector/exporter/sent_spans\""
                      aggregation = {
                        alignmentPeriod  = "60s"
                        perSeriesAligner = "ALIGN_RATE"
                      }
                    }
                  }
                  plotType       = "LINE"
                  legendTemplate = "Spans/s"
                }]
                yAxis = { scale = "LINEAR" }
              }
            }
          }
        ]
      )
    }
  })

  project = var.project_id
}

output "dashboard_url" {
  value       = "https://console.cloud.google.com/monitoring/dashboards/builder/${google_monitoring_dashboard.gateway.id}?project=${var.project_id}"
  description = "URL do dashboard no Cloud Monitoring"
}
