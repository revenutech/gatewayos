# Envoy gRPC-REST Transcoder

Envoy sidecar that translates REST requests to gRPC calls for LedgerOS.

## Why

KrakenD CE does not support native gRPC backends (Enterprise-only feature). An Envoy sidecar bridges this gap using the `grpc_json_transcoder` filter.

## Architecture

```
Client --> KrakenD :8080 --> Envoy :8085 (REST→gRPC) --> LedgerOS :9081 (gRPC/HTTP2)
```

- **Dev (Docker Compose):** Envoy runs as separate service at `envoy-grpc-transcoder:8085`
- **K8s (Sidecar):** Envoy runs in same pod at `127.0.0.1:8085`

## Configuration

Source: `envoy/envoy-dev.yaml`

### Listener

- Address: `:8085` (dev: 0.0.0.0, K8s: 127.0.0.1)
- Protocol: HTTP with AUTO codec detection

### Routes

| Match | Method | Timeout | gRPC Operation |
|-------|--------|---------|---------------|
| /grpc/v1/postings | POST | 5s | CreatePosting |
| /grpc/v1/postings/ | GET | 3s | GetPosting |
| /grpc/v1/balances | GET | 3s | GetBalance |
| /grpc/v1/settlements | POST | 10s | CreateSettlement |
| /grpc/v1/reconciliation | POST | 5s | CreateReconciliationJob |

### gRPC Transcoder Filter

```yaml
grpc_json_transcoder:
  proto_descriptor: /etc/envoy/proto/ledgeros.pb
  services:
    - revenu.ledgeros.v1.PostingService
    - revenu.ledgeros.v1.BalanceService
    - revenu.ledgeros.v1.SettlementService
    - revenu.ledgeros.v1.ReconciliationService
  print_options:
    preserve_proto_field_names: true
    always_print_primitive_fields: true
    always_print_enums_as_ints: false
  convert_grpc_status: true
  ignore_unknown_query_parameters: true
```

### Upstream Cluster

- Name: `ledgeros_grpc`
- Address: `ledgeros:9081`
- Protocol: HTTP/2 (explicit)
- DNS: STRICT_DNS
- Load balancing: ROUND_ROBIN
- Connect timeout: 2s

### Circuit Breaker (Envoy-level)

| Setting | Value |
|---------|-------|
| Max connections | 50 |
| Max pending requests | 50 |
| Max requests | 50 |
| Max retries | 3 |

### Admin Interface

- Port: 9901
- Health endpoint: `/ready` (used for liveness/readiness probes)

## Proto Descriptor

The transcoder requires a compiled proto descriptor file at `/etc/envoy/proto/ledgeros.pb`.

Generate from proto files:
```bash
protoc --descriptor_set_out=ledgeros.pb --include_imports *.proto
```

In K8s, the descriptor is stored in a ConfigMap (`ledgeros-proto-descriptor`).

## Resource Usage

| Setting | Value |
|---------|-------|
| CPU request | 50m |
| CPU limit | 200m |
| Memory request | 64Mi |
| Memory limit | 128Mi |

Minimal footprint — Envoy only transcodes, doesn't process business logic.
