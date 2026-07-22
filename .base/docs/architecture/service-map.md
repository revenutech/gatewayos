# Service Map

## Backend Services

| Service | Port | Protocol | Circuit Breaker | Description |
|---------|------|----------|----------------|-------------|
| LedgerOS | 8081 | HTTP | cb-ledgeros-posting | Core accounting — postings, balances, settlements, reconciliation |
| LedgerOS | 9081 | gRPC | cb-ledgeros-grpc | Same as above, via gRPC (through Envoy transcoder) |
| Paymentos | 8082 | HTTP | cb-paymentos | Payment processing — PIX, TED, Boleto |
| AtmOS | 8088 | HTTP | cb-atmos | ATM/Cash management |
| IdentityOS | 8091 | HTTP | cb-identityos | Identity & authentication services |
| OnboardOS | 8092 | HTTP | cb-onboardos | Customer onboarding (KYC, AML, due diligence) |
| AccountOS | 8093 | HTTP | cb-accountos | Account management |
| FinanceOS | 8095 | HTTP | cb-financeos | Financial operations |

## Infrastructure Dependencies

| Service | Port | Protocol | Purpose |
|---------|------|----------|---------|
| Keycloak | 8443/8080 | HTTPS | JWT validation (JWKS endpoint) |
| Redis | 6379 | TCP | Rate limiting, token revocation, caching, CB state |
| OTel Collector | 4317 | gRPC | Telemetry export (traces + metrics) |
| Envoy Transcoder | 8085 | HTTP | gRPC-REST transcoding (pod sidecar) |

## Service Discovery

### Docker Compose (Local Development)

Services are resolved by Docker Compose DNS using container names:

```
ledgeros:8081          paymentos:8082
atmos:8088             identityos:8091
onboardos:8092         accountos:8093
financeos:8095         envoy-grpc-transcoder:8085
redis:6379
```

### Kubernetes (Staging/Production)

Services use K8s DNS with full namespace resolution:

```
# Staging
ledgeros.ledgeros-staging.svc.cluster.local:8081
paymentos.ledgeros-staging.svc.cluster.local:8082
redis.ledgeros-staging.svc.cluster.local:6379

# Production
ledgeros.ledgeros-production.svc.cluster.local:8081
paymentos.ledgeros-production.svc.cluster.local:8082
redis.ledgeros-production.svc.cluster.local:6379
```

The gRPC transcoder switches from Docker DNS (`envoy-grpc-transcoder:8085`) to localhost (`127.0.0.1:8085`) in K8s since it runs as a sidecar container in the same pod.

## Circuit Breaker Configuration

All values are consistent across dev/staging/prod environments:

| Backend | Name | Max Errors | Interval (s) | Timeout (s) | Sensitivity |
|---------|------|-----------|---------------|-------------|-------------|
| LedgerOS HTTP | cb-ledgeros-posting | 5 | 60 | 10 | Standard |
| LedgerOS gRPC | cb-ledgeros-grpc | 5 | 60 | 10 | Standard |
| Paymentos | cb-paymentos | 3 | 60 | 15 | Strict — payment operations are critical |
| AtmOS | cb-atmos | 10 | 120 | 30 | Lenient — tolerates more errors, longer recovery |
| IdentityOS | cb-identityos | 2 | 30 | 5 | Very strict — auth must fail fast |
| OnboardOS | cb-onboardos | 5 | 60 | 10 | Standard |
| AccountOS | cb-accountos | 5 | 60 | 10 | Standard |
| FinanceOS | cb-financeos | 5 | 60 | 15 | Standard with longer recovery |

**Behavior:** When `max_errors` failures occur within `interval` seconds, the circuit opens for `timeout` seconds. KrakenD returns 503 to clients while open. Status changes are logged (`log_status_change: true`).

## Connection Patterns

### Direct HTTP

Most backends receive direct HTTP requests from KrakenD:

```
Client --> KrakenD :8080 --> Backend :port
```

Encoding is typically `no-op` (passthrough) for wildcard routes or `json` for specific endpoints.

### gRPC via Envoy Transcoder

LedgerOS also exposes gRPC services. Since KrakenD CE does not support native gRPC, an Envoy sidecar transcodes REST→gRPC:

```
Client --> KrakenD :8080 --> Envoy :8085 (REST→gRPC) --> LedgerOS :9081 (gRPC)
```

gRPC services exposed:
- `revenu.ledgeros.v1.PostingService`
- `revenu.ledgeros.v1.BalanceService`
- `revenu.ledgeros.v1.SettlementService`
- `revenu.ledgeros.v1.ReconciliationService`

### Aggregated Multi-Backend

Dashboard endpoints query multiple backends concurrently:

```
Client --> KrakenD :8080 --+--> LedgerOS :8081   (group: ledger)
                           +--> Paymentos :8082   (group: payments)
                           +--> AtmOS :8088       (group: automation)
                           +--> AccountOS :8093   (group: accounts)
```

Response is merged into a single JSON with grouped keys. Uses `concurrent_calls` for parallel execution and per-backend timeouts.

## Healthcheck Endpoints

| Endpoint | Purpose | Auth |
|----------|---------|------|
| `/__health` | KrakenD internal health (liveness probe) | None |
| `/__ready` | Backend readiness (proxies to LedgerOS /health) | None |
| `/__metrics` | Prometheus metrics | None (restricted via NetworkPolicy) |
