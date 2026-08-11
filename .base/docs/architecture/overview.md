# Architecture Overview

## 1. Context — Revenu Platform Ecosystem

The Gateway is the single entry point for all external traffic into the Revenu Platform. It sits between clients (web apps, mobile, external integrations) and the backend microservices.

```
                         Internet
                            |
                     [ Load Balancer ]
                     (GCE / nginx-ingress)
                            |
                   +------------------+
                   |  KrakenD Gateway  |
                   |  :8080 (API)      |
                   |  :8090 (metrics)  |
                   +--------+---------+
                            |
         +------------------+------------------+
         |          |          |          |     |
     LedgerOS  Paymentos   AtmOS   Identos  ...
      :8081      :8082     :8088    :8091
```

**External actors:**
- Web App (app.revenu.com.br / staging.revenu.com.br)
- Admin Dashboard
- API integrations (via API keys)
- Keycloak IdP (auth.revenu.tech)

## 2. Container View

The gateway pod runs **two containers** in a sidecar pattern:

```
+---------------------------------------------------------------+
|  Pod: krakend                                                  |
|                                                                |
|  +-------------------------+    +---------------------------+  |
|  | Container: krakend      |    | Container: envoy-grpc     |  |
|  | KrakenD v2.7            |    | Envoy v1.31               |  |
|  | :8080 API               |--->| :8085 gRPC transcoder     |  |
|  | :8090 metrics           |    | :9901 admin               |  |
|  +-------------------------+    +---------------------------+  |
|            |                               |                   |
+---------------------------------------------------------------+
             |                               |
    HTTP backends              gRPC backend (LedgerOS :9081)
```

**External dependencies:**
- **Keycloak** — JWKS endpoint for JWT validation
- **Redis** — Rate limiting, token revocation, response caching, circuit breaker state
- **OTel Collector** — Telemetry export (traces + metrics via gRPC :4317)

## 3. Component View — Request Lifecycle

```
Client Request
     |
     v
[1] CORS Validation .............. security/cors
     |
[2] Security Headers ............. security/http (HSTS, CSP, X-Frame-Options)
     |
[3] JWT Validation ............... auth/validator (RS256 via Keycloak JWKS)
     |
[4] Token Revocation Check ....... auth/revoker (Bloom filter, 10M tokens)
     |
[5] RBAC Check ................... auth/validator (roles from realm_access.roles)
     |
[6] Rate Limiting ................ qos/ratelimit/router (per X-Tenant-ID)
     |
[7] Lua Middleware ............... modifier/lua-endpoint (security policies, DLP, etc.)
     |
[8] Claim Propagation ........... sub -> X-User-ID, tenant_id -> X-Tenant-ID, etc.
     |
[9] Backend Routing .............. Host resolution + circuit breaker
     |
[10] Response .................... Back to client with security headers
```

## 4. Configuration Architecture

KrakenD uses **Flexible Configuration (FC)** — a Go template system that compiles per-environment settings into a final JSON config.

```
krakend/
  krakend.tmpl              <-- Main template (includes all endpoints + partials)
  settings/
    dev.json                <-- Dev: localhost backends, DEBUG logging
    staging.json            <-- Staging: K8s DNS, INFO logging
    prod.json               <-- Prod: K8s DNS, WARNING logging, higher rate limits
    service_routes.json     <-- Service discovery map
  endpoints/
    ledger_v1.json          <-- Per-module route definitions (13 files)
    paymentos_v1.json
    ...
  partials/
    jwt_validator.tmpl      <-- Reusable config fragments (18 .tmpl files)
    rate_limiter.tmpl
    circuit_breaker.tmpl
    lua/                    <-- 17 Lua scripts for enterprise features
  templates/
    protected_endpoint.tmpl <-- Generic endpoint templates
```

**Dev mode:** FC_ENABLE=1 — templates compiled at startup.
**Prod mode:** FC_ENABLE=0 — pre-compiled JSON baked into Docker image.

## 5. Key Design Decisions

| Decision | Rationale |
|----------|-----------|
| KrakenD CE over Kong/Envoy | Stateless, high-performance, native JWT + rate limiting, declarative config |
| Envoy sidecar for gRPC | KrakenD CE lacks native gRPC; Envoy transcoder bridges REST→gRPC |
| Lua scripts for enterprise features | Replaces KrakenD Enterprise features (DLP, tiered rate limiting, custom CB) at no license cost |
| Flexible Configuration | Environment-specific config without code duplication |
| Bloom filter + Redis for token revocation | Memory-efficient (10M tokens) + distributed real-time revocation |
| Multi-stage Docker build | Compile templates at build time for immutable prod images |
| Pod anti-affinity | Gateway replicas spread across nodes for HA |

## 6. Security Layers

1. **Network:** K8s NetworkPolicies (default-deny, explicit ingress/egress per backend)
2. **Transport:** TLS termination at ingress, mTLS for backend communication (TLS 1.2-1.3)
3. **Authentication:** JWT RS256 validation via Keycloak JWKS
4. **Authorization:** RBAC per endpoint (viewer/operator/admin roles)
5. **Rate Limiting:** Per-tenant via X-Tenant-ID (native + Redis-distributed)
6. **Resilience:** Circuit breakers per backend (native + custom Lua with half-open state)
7. **Data Protection:** DLP filter (PII masking), security policies enforcement
8. **Observability:** OpenTelemetry traces, Prometheus metrics, structured logging, audit evidence

## 7. Deployment Topology

| Environment | Cluster | Region | Domain | Replicas |
|-------------|---------|--------|--------|----------|
| Dev | gateway-dev-cluster | southamerica-east1-a | gateway.allenty.io | 2 |
| Staging | gateway-staging-cluster | southamerica-east1 | staging.revenu.com.br | 2-8 (HPA) |
| Production | gateway-prod-cluster | southamerica-east1 | app.revenu.com.br | 2-8 (HPA) |

All environments use GKE with Workload Identity Federation, Artifact Registry for images, and Helm for deployment.
