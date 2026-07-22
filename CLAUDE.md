# Gateway — Revenu Platform API Gateway

## Identity

Standalone KrakenD v2.9.4 (latest CE) API Gateway for the Revenu Platform. Routes external traffic to all backend modules with JWT validation, rate limiting, circuit breakers, and CORS.

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
  devopsfaith/krakend:2.9.4 \
  check -c /etc/krakend/krakend.tmpl   # validate config
```

## Project Map

| Path | What |
|------|------|
| `krakend/krakend.tmpl` | Main KrakenD template (Flexible Configuration) |
| `krakend/settings/{develop,sandbox,production}/` | Per-environment settings, one JSON per root key (loaded via `FC_SETTINGS`) |
| `krakend/settings/{develop,sandbox,production}.json` | Same settings, flat form (used by `tools/compile-config.sh`) |
| `krakend/settings/service_routes.json` | Service map (host:port per module) |
| `krakend/endpoints/*.json` | Route definitions per module (ledger, paymentos, identityos, atmos, admin, health) |
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
| IdentityOS | `http://identityos:8091` | `identityos.ledgeros-production.svc.cluster.local` | :8091 |

## Security

- **JWT:** RS256 via Keycloak JWKS endpoint, claims propagated (sub, tenant_id, roles)
- **RBAC:** Role-based per endpoint (ledger-viewer, ledger-operator, ledger-admin)
- **Rate Limiting:** Per-tenant via X-Tenant-ID header
- **Circuit Breakers:** Per-backend (configurable max_errors, interval, timeout)
- **CORS:** Strict per-environment origins
- **Security Headers:** HSTS, X-Frame-Options DENY, CSP, referrer policy
- **Token Revocation:** Bloom filter (10M tokens, 0.1% FPR)
- **Network Policies:** Explicit ingress/egress per backend

## ISO 27001 Compliance

This gateway maintains an ISMS (Information Security Management System) compliant with ISO/IEC 27001:2022, ISO 27002, 27003, 27004, and 27005.

### ISMS Documentation

| Document | Path | ISO Ref |
|----------|------|---------|
| ISMS Scope Statement | `.base/docs/isms/scope-statement.md` | Cl. 4.3 |
| Security Policy (B1-GW) | `.base/docs/isms/information-security-policy.md` | Cl. 5.2 |
| Roles & RACI | `.base/docs/isms/roles-responsibilities.md` | Cl. 5.3 |
| Interested Parties | `.base/docs/isms/interested-parties.md` | Cl. 4.2 |
| ISMS Manual | `.base/docs/isms/isms-manual.md` | Cl. 4.4 |
| Risk Methodology | `.base/docs/risk/risk-methodology.md` | 27005 |
| Risk Register | `.base/docs/risk/risk-register.md` | 27005 |
| Statement of Applicability | `.base/docs/risk/statement-of-applicability.md` | Cl. 6.1.3d |
| STRIDE Threat Model | `.base/docs/risk/threat-model.md` | 27005 |
| Controls Matrix (93) | `.base/docs/compliance/controls-matrix.md` | Annex A |
| Security Metrics | `.base/docs/metrics/security-metrics-framework.md` | 27004 |
| IRP | `.base/docs/operations/incident-response-plan.md` | A.5.24-28 |
| BCP | `.base/docs/operations/business-continuity-plan.md` | A.5.29-30 |
| Change Management | `.base/docs/operations/change-management.md` | A.8.32 |
| Runbooks | `.base/docs/operations/runbooks/` | A.5.37 |

### Compliance CI

The `.github/workflows/compliance.yml` pipeline validates ISO compliance on every PR:
- Config validation (A.8.9)
- ISMS document completeness (A.5.28)
- JWT security settings (A.8.5)
- Network policy presence (A.8.20)

### ISO Annotations

All config files include ISO 27001 Annex A control references in comments. When modifying files, preserve these annotations.

### Derived From

LedgerOS ISO 27000 documentation: `ledgeros/.base/knowledge/iso27000/`, `ledgeros/.base/plans/08-security/`

## GCP Deployment

```bash
# Terraform (infra)
cd deployment/infra/gcp/environments/dev && terraform apply

# Helm (app)
helm upgrade --install gateway k8s/helm/gateway -f k8s/helm/gateway/values-gcp-dev.yaml

# CD pipelines (auto)
# develop branch → cd-dev-gcp.yml        → GKE develop    (KRAKEND_ENV=develop)
# staging branch → cd-staging-gcp.yml    → GKE sandbox    (KRAKEND_ENV=sandbox, + Cosign sign)
# v*.*.* tag     → cd-production-gcp.yml → GKE production (KRAKEND_ENV=production, approval + SBOM + Trivy)
#
# Three environments only. Tags for production are cut from `main`.
# uat/sit/sqa belong to the separate BASA project, not to revenu-platform.
```

| Path | What |
|------|------|
| `deployment/infra/gcp/` | Terraform modules (VPC, GKE, AR, KMS, DNS, Monitoring) |
| `deployment/infra/gcp/environments/` | Per-env configs (dev/staging/prod) |
| `k8s/helm/gateway/` | Helm chart (14 templates + 3 GCP values) |
| `.github/workflows/cd-*-gcp.yml` | CD pipelines (develop/sandbox/production) |

## Adding a New Module

1. Add backend address to `krakend/settings/{develop,sandbox,production}/backends.json` (and the flat `.json` equivalents)
2. Add circuit breaker config under `cb_{module}`
3. Create `krakend/endpoints/{module}_v1.json` with route definitions
4. Include in `krakend/krakend.tmpl` endpoints array
5. Add egress rule in `k8s/policies/krakend-egress.yaml`
6. Update `krakend/settings/service_routes.json`
