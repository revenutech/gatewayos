# ADR-001: KrakenD as API Gateway

## Status

Accepted

## Context

The Revenu Platform is a multi-module financial platform (LedgerOS, Paymentos, AtmOS, IdentityOS, OnboardOS, AccountOS, FinanceOS) that needs a unified API gateway for:

- Single entry point for all external traffic
- JWT validation and RBAC enforcement
- Per-tenant rate limiting
- Circuit breaker protection per backend
- CORS management across environments
- gRPC support for LedgerOS
- Observability (metrics, traces, structured logging)
- ISO 27001 compliance requirements

## Options Considered

### 1. Kong Gateway
- **Pros:** Rich plugin ecosystem, database-backed dynamic config, admin API
- **Cons:** Stateful (requires PostgreSQL/Cassandra), heavier resource footprint, Lua-based plugins are complex, enterprise features require license

### 2. Envoy Proxy (standalone)
- **Pros:** Native gRPC support, high performance, xDS dynamic config
- **Cons:** Complex configuration (YAML-heavy), limited built-in JWT validation, no native rate limiting (requires external service), steep learning curve

### 3. Custom Gateway (Go/Rust)
- **Pros:** Full control, exact feature match
- **Cons:** High development cost, maintenance burden, security risk from custom auth code

### 4. KrakenD CE (chosen)
- **Pros:** Stateless, declarative JSON config, built-in JWT/RBAC/rate limiting/circuit breakers, Flexible Configuration for multi-env, high performance (~50k req/s per instance), Lua extensibility
- **Cons:** No native gRPC in CE (Enterprise only), no dynamic config API, template syntax learning curve

## Decision

Use **KrakenD v2.7 Community Edition** with:

1. **Flexible Configuration** for environment-specific deployments (dev/staging/prod)
2. **Envoy sidecar** for gRPC-REST transcoding (compensates for CE gRPC limitation)
3. **Lua scripts** to replicate KrakenD Enterprise features (DLP, tiered rate limiting, custom circuit breakers, API key validation)
4. **Redis** for distributed state (rate limiting, token revocation, response caching)

## Consequences

### Positive

- **Stateless architecture** — no database dependency, easy horizontal scaling via HPA
- **Declarative config** — all routing is version-controlled, auditable, CI-validated
- **Performance** — KrakenD is one of the fastest API gateways available
- **Cost** — CE is free; avoided KrakenD Enterprise license
- **Compliance** — Declarative config maps cleanly to ISO 27001 controls (A.8.9 Configuration Management)

### Negative

- **gRPC requires Envoy sidecar** — additional container per pod, proto descriptor management
- **Enterprise features via Lua** — custom code to maintain (17 Lua scripts), less battle-tested than native features
- **No dynamic config** — config changes require pod restart (mitigated by config hash annotation for rolling updates)
- **Template complexity** — FC templates with Go syntax can be error-prone (mitigated by CI validation)

### Risks

| Risk | Mitigation |
|------|-----------|
| Lua scripts have bugs | Enterprise feature test suite (35 tests), CI audit |
| Config template errors | `krakend check` in CI, JSON linting, config audit script |
| Envoy sidecar adds latency | localhost communication (~0.1ms), acceptable for gRPC benefits |
| KrakenD CE deprecates Lua | Enterprise migration path exists; Lua API is stable |

## Related

- [Service Map](../service-map.md) — Backend connections and circuit breaker configs
- [Auth Flow](../auth-flow.md) — JWT validation and RBAC implementation
- Envoy gRPC configuration: `envoy/envoy-dev.yaml`
- Lua scripts: `krakend/partials/lua/`
