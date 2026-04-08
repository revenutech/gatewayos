# Partials Reference

Partials are reusable configuration fragments included via `{{ template "name.tmpl" . }}` in endpoint definitions.

## Authentication & Authorization

### jwt_validator.tmpl

JWT RS256 validation via Keycloak JWKS.

```json
"auth/validator": {
  "alg": "RS256",
  "jwk_url": "{{ .keycloak.jwks_url }}",
  "issuer": "{{ .keycloak.issuer }}",
  "audience": ["{{ .keycloak.audience }}"],
  "cache": true,
  "cache_duration": 3600,
  "propagate_claims": [
    ["sub", "x-user-id"],
    ["tenant_id", "x-tenant-id"],
    ["realm_access.roles", "x-roles"],
    ["jti", "x-jwt-jti"],
    ["subscription_tier", "x-subscription-tier"]
  ]
}
```

### api_key_validator.tmpl

Lua-based API key authentication. Reads keys from pipe-delimited registry string in settings.

- **Script:** `lua/api_key_auth.lua`
- **Hook:** pre_proxy
- **Config source:** `{{ .api_keys.registry }}`

### oauth2_client.tmpl

OAuth2 client credentials flow for machine-to-machine auth.

```json
"auth/client-credentials": {
  "client_id": "{{ .oauth2.client_id }}",
  "token_url": "{{ .keycloak.issuer }}/protocol/openid-connect/token",
  "scopes": "openid"
}
```

## Rate Limiting

### rate_limiter.tmpl

Native KrakenD rate limiter. Per-tenant via X-Tenant-ID header.

```json
"qos/ratelimit/router": {
  "max_rate": {{ .rate_limit.global_max }},
  "client_max_rate": {{ .rate_limit.tenant_max }},
  "strategy": "header",
  "key": "X-Tenant-ID",
  "every": "1m"
}
```

### rate_limiter_tiered.tmpl

Lua-based tiered rate limiting. Uses X-Subscription-Tier header + Redis for tier-specific limits.

- **Script:** `lua/tiered_rate_limit.lua`
- **Hook:** pre_proxy
- **Redis:** required

### redis_rate_limiter.tmpl

Lua-based distributed rate limiting via Redis. Sliding window (60s).

- **Script:** `lua/redis_rate_limit.lua`
- **Hook:** pre_proxy
- **Config:** global_max, tenant_max, window_seconds=60
- **Redis:** required

## Resilience

### circuit_breaker.tmpl

Native KrakenD circuit breaker.

```json
"qos/circuit-breaker": {
  "interval": {{ .cb_interval }},
  "timeout": {{ .cb_timeout }},
  "max_errors": {{ .cb_max_errors }},
  "name": "{{ .cb_name }}",
  "log_status_change": true
}
```

### circuit_breaker_custom.tmpl

Lua-based CB with Redis-backed state and half-open support (max 3 probes).

- **Script:** `lua/circuit_breaker_custom.lua`
- **Hook:** pre_proxy + post_proxy
- **Redis:** required

### response_cache.tmpl

Redis-based response caching. Pre-proxy checks cache, post-proxy stores response.

- **Script:** `lua/response_cache.lua`
- **Hook:** pre_proxy + post_proxy
- **Config:** cache_ttl (default 60s)
- **Redis:** required

## Security

### security_headers.tmpl

HTTP security headers applied globally.

```json
"security/http": {
  "sts_seconds": 31536000,
  "sts_include_subdomains": true,
  "frame_deny": true,
  "content_type_nosniff": true,
  "browser_xss_filter": true,
  "content_security_policy": "default-src 'self'",
  "referrer_policy": "strict-origin-when-cross-origin",
  "custom_frame_options_value": "DENY"
}
```

### security_policies.tmpl

Lua-based security policy enforcement.

- **Script:** `lua/security_policies.lua`
- **Hook:** pre_proxy
- **ISO:** A.5.1

### web_filter.tmpl

SSRF prevention and URL blocklist.

- **Script:** `lua/web_filter.lua`
- **Hook:** pre_proxy
- **ISO:** A.8.23

### dlp_filter.tmpl

Data leakage prevention / PII protection in responses.

- **Script:** `lua/dlp.lua`
- **Hook:** post_proxy
- **ISO:** A.8.12, A.5.34

### bloom_filter.tmpl

Token revocation via Bloom filter.

```json
"auth/revoker": {
  "N": 10000000,
  "P": 0.0000001,
  "hash_name": "optimal",
  "TTL": 3600,
  "port": 1234,
  "token_keys": ["jti"]
}
```

### token_revocation.tmpl

Lua-based token revocation check via Redis blacklist.

- **Script:** `lua/token_revocation.lua`
- **Hook:** pre_proxy
- **Redis:** required

### mtls_backend.tmpl

mTLS for backend connections.

```json
"backend/http/client": {
  "client_tls": {
    "ca_certs": "/etc/krakend/tls/ca.crt",
    "client_certs": [{ "certificate": "client.crt", "private_key": "client.key" }],
    "min_version": "TLS12",
    "max_version": "TLS13"
  }
}
```

## Telemetry

### telemetry.tmpl

OpenTelemetry + Prometheus metrics.

- **OTLP exporter:** otel-collector:4317 (gRPC)
- **Prometheus:** :8090, collection_time 30s
- **Layers:** global, proxy, backend (all with report_headers)

### cors.tmpl

CORS configuration from environment settings.

```json
"security/cors": {
  "allow_origins": {{ marshal .cors.allow_origins }},
  "expose_headers": ["X-Request-ID", "X-Correlation-ID"],
  "allow_credentials": true
}
```

## Observability

### access_log.tmpl

Structured access logging.

- **Script:** `lua/access_log.lua`
- **Hook:** post_proxy

### audit_evidence.tmpl

ISO 27001 audit evidence collection.

- **Script:** `lua/audit_evidence.lua`
- **Hook:** post_proxy
- **ISO:** A.5.28, A.8.15

### business_metrics.tmpl

Business event metrics to Redis.

- **Script:** `lua/business_metrics.lua`
- **Hook:** post_proxy
- **Redis:** required

### json_schema_validator.tmpl

JSON request body schema validation.

- **Script:** `lua/json_schema_validator.lua`
- **Hook:** pre_proxy

## Utility

### backend_headers.tmpl

Standard input headers and query string passthrough.

```json
"input_headers": ["X-User-ID", "X-Tenant-ID", "X-Roles", "X-Correlation-ID", "Content-Type", "Accept"],
"input_query_strings": ["*"]
```
