# OpenTelemetry

Distributed tracing and metrics via OpenTelemetry.

## Configuration

```json
"telemetry/opentelemetry": {
  "service_name": "krakend-gateway",
  "service_version": "1.0.0",
  "exporters": {
    "otlp": [{
      "name": "otel-collector",
      "host": "otel-collector",
      "port": 4317,
      "use_http": false
    }]
  },
  "layers": {
    "global": { "report_headers": true },
    "proxy": { "report_headers": true },
    "backend": {
      "metrics": { "report_headers": true },
      "traces": { "report_headers": true }
    }
  }
}
```

## Exporter

| Setting | Value |
|---------|-------|
| Protocol | OTLP gRPC |
| Host | otel-collector |
| Port | 4317 |
| HTTP mode | false (gRPC) |

Network policy allows egress to otel-collector in the `monitoring` namespace on port 4317/TCP.

## Instrumentation Layers

| Layer | Scope | Data |
|-------|-------|------|
| Global | Full request lifecycle | Request/response headers, overall latency |
| Proxy | Gateway → backend proxy | Proxy timing, header propagation |
| Backend | Per-backend call | Backend latency, response headers, individual backend traces |

All layers have `report_headers: true` for full observability.

## Trace Context

KrakenD propagates standard trace context headers:
- `traceparent` (W3C Trace Context)
- `X-Correlation-ID` (custom, propagated to backends)

## Service Identity

- **Service name:** `krakend-gateway`
- **Service version:** `1.0.0`

These appear as resource attributes in all exported spans and metrics.
