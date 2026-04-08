# Grafana Dashboards

## Security Dashboard

File: `k8s/manifests/grafana-dashboard-security.json`

### Purpose

Visualizes security-related metrics for the gateway, aligned with ISO 27001 monitoring requirements.

### Panels

Expected panels cover:
- Authentication failure rate (401/403 over time)
- Rate limiting activity (429 responses)
- Circuit breaker status per backend
- Request volume by endpoint
- Error rate trends
- Latency percentiles (p50, p95, p99)

### Import

To import into Grafana:
1. Navigate to Dashboards → Import
2. Upload the JSON file or paste its contents
3. Select the Prometheus data source
4. Save

### Data Source

Requires a Prometheus data source scraping the KrakenD ServiceMonitor (port 8090, path /__metrics, 15s interval).

### Variables

Dashboard may use template variables:
- `$namespace` — Kubernetes namespace
- `$service` — Service name (krakend)
- `$backend` — Backend service filter
