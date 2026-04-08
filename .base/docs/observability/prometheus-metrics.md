# Prometheus Metrics

KrakenD exposes metrics on port `:8090` at path `/__metrics` in Prometheus format.

## Configuration

```json
"telemetry/metrics": {
  "collection_time": "30s",
  "listen_address": ":8090"
}
```

## Key Metrics

### Request Metrics

| Metric | Type | Labels | Description |
|--------|------|--------|-------------|
| `krakend_router_response_size_count` | Counter | status, endpoint | Total requests by status code |
| `krakend_router_response_time_seconds_bucket` | Histogram | le | Response time distribution |

### Circuit Breaker Metrics

| Metric | Type | Labels | Description |
|--------|------|--------|-------------|
| `krakend_circuit_breaker_open` | Gauge | name | 1 if CB is open, 0 if closed |

### Backend Metrics

| Metric | Type | Labels | Description |
|--------|------|--------|-------------|
| `krakend_backend_response_size_count` | Counter | status, backend | Backend response counter |
| `krakend_backend_response_time_seconds_bucket` | Histogram | le, backend | Backend latency |

## ServiceMonitor

```yaml
endpoints:
  - port: metrics
    path: /__metrics
    interval: 15s
    scrapeTimeout: 10s
```

## Useful PromQL Queries

### Error Rate

```promql
sum(rate(krakend_router_response_size_count{status=~"5.."}[5m]))
/ sum(rate(krakend_router_response_size_count[5m]))
```

### p95 Latency

```promql
histogram_quantile(0.95,
  sum(rate(krakend_router_response_time_seconds_bucket[5m])) by (le)
)
```

### Requests per Second

```promql
sum(rate(krakend_router_response_size_count[1m]))
```

### Rate Limited Requests

```promql
sum(rate(krakend_router_response_size_count{status="429"}[5m]))
```

### Per-Tenant Error Rate

```promql
sum by (tenant_id) (rate(krakend_router_response_size_count{status=~"5.."}[1h]))
/ sum by (tenant_id) (rate(krakend_router_response_size_count[1h]))
```
