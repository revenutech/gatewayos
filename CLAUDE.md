# Gateway — Revenu Platform API Gateway

## Identity

Standalone KrakenD v2.7 API Gateway for the Revenu Platform. Routes external traffic to all backend modules with JWT validation, rate limiting, circuit breakers, and CORS.

**Extracted from:** `ledgeros/krakend/` + `ledgeros/k8s/infrastructure/krakend/` (v1.0.0)

## Quick Commands

```bash
docker compose up              # run locally (:8080 API, :8090 metrics)
docker run --rm \
  -v ./krakend:/etc/krakend \
  -e FC_ENABLE=1 \
  -e FC_SETTINGS=/etc/krakend/settings \
  -e FC_PARTIALS=/etc/krakend/partials \
  -e FC_TEMPLATES=/etc/krakend/templates \
  devopsfaith/krakend:2.7 \
  check -c /etc/krakend/krakend.tmpl   # validate config
```

## Project Map

| Path | What |
|------|------|
| `krakend/krakend.tmpl` | Main KrakenD template (Flexible Configuration) |
| `krakend/settings/{dev,staging,prod}.json` | Per-environment settings (backends, CORS, rate limits, circuit breakers) |
| `krakend/settings/service_routes.json` | Service map (host:port per module) |
| `krakend/endpoints/*.json` | Route definitions per module (ledger, paymentos, identos, atmos, admin, health) |
| `krakend/partials/*.tmpl` | Reusable config fragments (JWT, rate limiter, circuit breaker, CORS, telemetry, security headers, bloom filter) |
| `krakend/templates/protected_endpoint.tmpl` | Generic protected endpoint template |
| `k8s/manifests/` | K8s manifests (deployment, service, ingress, HPA, PDB, configmap, serviceaccount, servicemonitor, prometheusrule) |
| `k8s/policies/` | Network policies (ingress + egress) |
| `Dockerfile` | Production container image |
| `docker-compose.yml` | Local development |
| `.github/workflows/ci.yml` | CI pipeline (validate config + docker build) |

## Backend Modules

| Backend | Dev Address | Prod K8s DNS | Port |
|---------|------------|--------------|------|
| LedgerOS | `http://ledgeros:8081` | `ledgeros.ledgeros-production.svc.cluster.local` | :8081/:9081 |
| Paymentos | `http://paymentos:8082` | `paymentos.ledgeros-production.svc.cluster.local` | :8082 |
| AtmOS | `http://atmos:8088` | `atmos.ledgeros-production.svc.cluster.local` | :8088 |
| Identos | `http://identos:8091` | `identos.ledgeros-production.svc.cluster.local` | :8091 |

## Security

- **JWT:** RS256 via Keycloak JWKS endpoint, claims propagated (sub, tenant_id, roles)
- **RBAC:** Role-based per endpoint (ledger-viewer, ledger-operator, ledger-admin)
- **Rate Limiting:** Per-tenant via X-Tenant-ID header
- **Circuit Breakers:** Per-backend (configurable max_errors, interval, timeout)
- **CORS:** Strict per-environment origins
- **Security Headers:** HSTS, X-Frame-Options DENY, CSP, referrer policy
- **Token Revocation:** Bloom filter (10M tokens, 0.1% FPR)
- **Network Policies:** Explicit ingress/egress per backend

## Adding a New Module

1. Add backend address to `krakend/settings/{dev,staging,prod}.json` under `backends`
2. Add circuit breaker config under `cb_{module}`
3. Create `krakend/endpoints/{module}_v1.json` with route definitions
4. Include in `krakend/krakend.tmpl` endpoints array
5. Add egress rule in `k8s/policies/krakend-egress.yaml`
6. Update `krakend/settings/service_routes.json`
