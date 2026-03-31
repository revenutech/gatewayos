# KrakenD Templates

Reusable endpoint templates in `krakend/templates/` that generate complete endpoint definitions.

## protected_endpoint.tmpl

Generic protected endpoint with JWT, RBAC, rate limiting, and circuit breaker.

### Parameters

| Parameter | Required | Default | Description |
|-----------|----------|---------|-------------|
| endpoint | Yes | — | Gateway path (e.g., `/v1/resource`) |
| method | Yes | — | HTTP method |
| roles | Yes | — | Allowed roles array |
| backend_host | Yes | — | Backend host URL |
| backend_path | Yes | — | Backend URL pattern |
| encoding | No | `json` | Response encoding |
| backend_encoding | No | `json` | Backend response encoding |
| rate_limit | Yes | — | Rate limit config object |
| cb_* | Yes | — | Circuit breaker config |

### Template Source

```go
{{ define "protected_endpoint" }}
{
  "endpoint": "{{ .endpoint }}",
  "method": "{{ .method }}",
  "input_headers": ["X-User-ID", "X-Tenant-ID", "X-Roles", "X-Correlation-ID", "Content-Type"],
  "output_encoding": "{{ or .encoding "json" }}",
  "extra_config": {
    {{ template "jwt_validator.tmpl" $ }},
    "auth/validator": {
      "roles_key": "realm_access.roles",
      "roles": {{ marshal .roles }}
    },
    {{ template "rate_limiter.tmpl" . }}
  },
  "backend": [{
    "host": ["{{ .backend_host }}"],
    "url_pattern": "{{ .backend_path }}",
    "encoding": "{{ or .backend_encoding "json" }}",
    "extra_config": {
      {{ template "circuit_breaker.tmpl" . }}
    }
  }]
}
{{ end }}
```

### Usage

```json
{{ template "protected_endpoint" (dict
  "endpoint" "/v1/resource"
  "method" "GET"
  "roles" (list "ledger-viewer" "ledger-admin")
  "backend_host" .backends.ledgeros_http
  "backend_path" "/v1/resource"
  "rate_limit" .balances_read.rate_limit
  "cb_name" .cb_posting.cb_name
  "cb_max_errors" .cb_posting.cb_max_errors
  "cb_interval" .cb_posting.cb_interval
  "cb_timeout" .cb_posting.cb_timeout
) }}
```

## dynamic_routing_endpoint.tmpl

Endpoint template that uses JWT claims to construct backend paths. Enables tenant-scoped and user-scoped data access.

### Parameters

| Parameter | Required | Default | Description |
|-----------|----------|---------|-------------|
| endpoint | Yes | — | Gateway path |
| method | Yes | — | HTTP method |
| roles | Yes | — | Allowed roles array |
| backend_host | Yes | — | Backend host URL |
| backend_path | Yes | — | Backend path with `{JWT.claim}` placeholders |
| cb | Yes | — | Circuit breaker config object |
| encoding | No | `json` | Response encoding |

### Template Source

```go
{{ define "dynamic_routing_endpoint" }}
{
  "endpoint": "{{ .endpoint }}",
  "method": "{{ .method }}",
  "input_headers": ["X-User-ID", "X-Tenant-ID", "X-Roles", "X-Correlation-ID",
                     "Content-Type", "X-Subscription-Tier"],
  "output_encoding": "{{ or .encoding "json" }}",
  "extra_config": {
    {{ template "jwt_validator.tmpl" $ }},
    "auth/validator": {
      "roles_key": "realm_access.roles",
      "roles_key_is_nested": true,
      "roles": {{ marshal .roles }}
    }
  },
  "backend": [{
    "host": ["{{ .backend_host }}"],
    "url_pattern": "{{ .backend_path }}",
    "encoding": "{{ or .backend_encoding "json" }}",
    "extra_config": {
      {{ template "circuit_breaker.tmpl" .cb }}
    }
  }]
}
{{ end }}
```

### Usage

```json
{{ template "dynamic_routing_endpoint" (dict
  "endpoint" "/v1/my-resource"
  "method" "GET"
  "roles" (list "ledger-viewer" "ledger-admin")
  "backend_host" .backends.ledgeros_http
  "backend_path" "/internal/v1/tenants/{JWT.tenant_id}/resource"
  "cb" .cb_posting
) }}
```

### Supported JWT Placeholders

| Placeholder | Resolves To | Use Case |
|-------------|-------------|----------|
| `{JWT.tenant_id}` | Tenant ID from token | Tenant-scoped queries |
| `{JWT.sub}` | User subject (ID) | User-scoped queries |

KrakenD CE natively supports `{JWT.claim}` interpolation in `url_pattern`. The claim value is extracted from the validated JWT and injected into the URL before proxying.

## Comparison

| Feature | protected_endpoint | dynamic_routing_endpoint |
|---------|-------------------|-------------------------|
| JWT validation | Yes | Yes |
| RBAC | Yes | Yes (nested) |
| Rate limiting | Yes (included) | No (add separately) |
| JWT claim routing | No | Yes (`{JWT.claim}` in url_pattern) |
| X-Subscription-Tier | No | Yes (in headers) |
