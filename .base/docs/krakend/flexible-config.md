# Flexible Configuration

KrakenD's Flexible Configuration (FC) is a Go template system that compiles environment-specific settings into a final JSON config at startup.

## How It Works

```
krakend.tmpl + settings/{env}.json + partials/*.tmpl + templates/*.tmpl
                          |
                    FC Template Engine (Go templates)
                          |
                    krakend.json (compiled)
```

## Environment Variables

| Variable | Value | Purpose |
|----------|-------|---------|
| `FC_ENABLE` | `1` | Enable Flexible Configuration |
| `FC_SETTINGS` | `/etc/krakend/settings` | Directory with per-env JSON files |
| `FC_PARTIALS` | `/etc/krakend/partials` | Directory with reusable template fragments |
| `FC_TEMPLATES` | `/etc/krakend/templates` | Directory with endpoint templates |
| `FC_OUT` | `/etc/krakend/compiled-krakend.json` | Output path for compiled config (optional) |

## Directory Structure

```
krakend/
  krakend.tmpl                    # Main template — entry point
  settings/
    dev.json                      # Dev settings (localhost backends, DEBUG)
    staging.json                  # Staging settings (K8s DNS, INFO)
    prod.json                     # Prod settings (K8s DNS, WARNING)
    service_routes.json           # Service discovery map
  endpoints/
    health.json                   # Health check endpoint
    ledger_v1.json                # LedgerOS HTTP routes
    ledger_grpc_v1.json           # LedgerOS gRPC routes
    ledger_dynamic_v1.json        # LedgerOS JWT-scoped routes
    paymentos_v1.json             # Payment routes
    identityos_v1.json               # Identity routes
    atmos_v1.json                 # ATM routes
    admin_v1.json                 # Admin routes
    onboardos_v1.json             # Onboarding routes (21 prefixes)
    accountos_v1.json             # Account routes
    financeos_v1.json             # Finance routes
    dashboard_v1.json             # Aggregated dashboard routes
    test_v1.json                  # Test endpoints
  partials/
    jwt_validator.tmpl            # JWT validation config
    rate_limiter.tmpl             # Rate limiting config
    circuit_breaker.tmpl          # Circuit breaker config
    cors.tmpl                     # CORS config
    telemetry.tmpl                # OpenTelemetry + Prometheus
    security_headers.tmpl         # Security headers
    bloom_filter.tmpl             # Token revocation
    ...                           # 18 .tmpl files total
    lua/                          # 17 Lua scripts
  templates/
    protected_endpoint.tmpl       # Generic protected endpoint
    dynamic_routing_endpoint.tmpl # JWT claim-based routing
```

## Template Syntax

FC uses Go template syntax within JSON:

```json
{
  "port": {{ .service.port }},
  "backend": ["{{ .backends.ledgeros_http }}"],
  "allow_origins": {{ marshal .cors.allow_origins }}
}
```

### Key Functions

| Function | Usage | Purpose |
|----------|-------|---------|
| `{{ .var }}` | `{{ .service.port }}` | Access settings value |
| `{{ marshal }}` | `{{ marshal .cors.allow_origins }}` | Serialize to JSON (arrays, objects) |
| `{{ template }}` | `{{ template "jwt_validator.tmpl" . }}` | Include a partial |
| `{{ if }}` | `{{ if .keycloak.disable_jwk_security }}` | Conditional |
| `{{ or }}` | `{{ or .encoding "json" }}` | Default value |
| `{{ define }}` | `{{ define "protected_endpoint" }}` | Define reusable template block |

## Settings File Structure

Each environment JSON file contains these top-level keys:

```json
{
  "keycloak": { "jwks_url": "...", "issuer": "...", "audience": "..." },
  "oauth2": { "client_id": "...", "client_secret": "..." },
  "api_keys": { "registry": "..." },
  "service": { "port": 8080, "log_level": "...", "return_error_msg": false },
  "backends": { "ledgeros_http": "...", "paymentos": "...", ... },
  "redis": { "host": "...", "port": "6379" },
  "rate_limit": { "global_max": 5000, "tenant_max": 500 },
  "cors": { "allow_origins": [...], ... },
  "cb_posting": { "cb_name": "...", "cb_max_errors": 5, ... },
  "postings_write": { "rate_limit": { ... } },
  "balances_read": { "rate_limit": { ... } }
}
```

## Compilation

### Development (live templates)

Docker Compose runs with `FC_ENABLE=1` — templates are compiled at KrakenD startup:

```bash
docker compose up  # FC_ENABLE=1, templates compiled on start
```

### Production (pre-compiled)

The Dockerfile uses a multi-stage build:

```dockerfile
# Stage 1: Compile templates to static JSON
FROM python:3.12-alpine AS compiler
COPY krakend/ /etc/krakend/
RUN sh /compile-config.sh

# Stage 2: Run with pre-compiled config
FROM devopsfaith/krakend:2.9.4
COPY --from=compiler /etc/krakend/krakend.json /etc/krakend/krakend.json
ENV FC_ENABLE=0  # Templates already compiled
```

### Manual Compilation

```bash
bash tools/compile-config.sh
```

## Config Validation

```bash
docker run --rm \
  -v ./krakend:/etc/krakend \
  -e FC_ENABLE=1 \
  -e FC_SETTINGS=/etc/krakend/settings \
  -e FC_PARTIALS=/etc/krakend/partials \
  -e FC_TEMPLATES=/etc/krakend/templates \
  devopsfaith/krakend:2.9.4 \
  check -c /etc/krakend/krakend.tmpl
```

This validates template syntax, JSON structure, and KrakenD schema compliance.
