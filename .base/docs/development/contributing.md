# Contributing Guide

## Adding a New Backend Module

1. **Add backend address** to `krakend/settings/{dev,staging,prod}.json`:
   ```json
   "backends": {
     "newmodule": "http://newmodule:8099"
   }
   ```

2. **Add circuit breaker config** to all 3 settings files:
   ```json
   "cb_newmodule": {
     "cb_name": "cb-newmodule",
     "cb_max_errors": 5,
     "cb_interval": 60,
     "cb_timeout": 10
   }
   ```

3. **Create endpoint file** `krakend/endpoints/newmodule_v1.json`:
   ```json
   {
     "endpoint": "/v1/newmodule/{path}",
     "method": "GET",
     "input_headers": ["X-User-ID", "X-Tenant-ID", "X-Roles", "X-Correlation-ID"],
     "output_encoding": "no-op",
     "extra_config": {
       {{ template "jwt_validator.tmpl" . }},
       "auth/validator": {
         "roles_key": "realm_access.roles",
         "roles_key_is_nested": true,
         "roles": ["ledger-viewer", "ledger-operator", "ledger-admin"]
       }
     },
     "backend": [{
       "host": ["{{ .backends.newmodule }}"],
       "url_pattern": "/v1/newmodule/{path}",
       "encoding": "no-op",
       "extra_config": {
         {{ template "circuit_breaker.tmpl" .cb_newmodule }}
       }
     }]
   }
   ```

4. **Include in krakend.tmpl**:
   ```json
   ,{{ template "endpoints/newmodule_v1.json" . }}
   ```

5. **Add egress rule** in `k8s/policies/krakend-egress.yaml`:
   ```yaml
   - to:
       - podSelector:
           matchLabels:
             app.kubernetes.io/name: newmodule
     ports:
       - protocol: TCP
         port: 8099
   ```

6. **Update service_routes.json**:
   ```json
   "newmodule": {
     "host": "newmodule",
     "port": 8099,
     "protocol": "http"
   }
   ```

## Adding Endpoints to Existing Module

1. Edit the module's endpoint file in `krakend/endpoints/`
2. Follow the RBAC pattern:
   - GET: `["ledger-viewer", "ledger-operator", "ledger-admin"]`
   - POST/PUT: `["ledger-operator", "ledger-admin"]`
   - DELETE: `["ledger-admin"]`
3. Use `{{ template "jwt_validator.tmpl" . }}` for auth
4. Use `{{ template "circuit_breaker.tmpl" .cb_modulename }}` for resilience
5. Validate: `docker run ... krakend check`

## Routing Patterns

### Wildcard (most modules)

```json
"endpoint": "/v1/module/{path}",
"url_pattern": "/v1/module/{path}"
```

Simple, catches all sub-routes. Backend controls routing.

### Explicit (LedgerOS)

```json
"endpoint": "/v1/postings",
"url_pattern": "/v1/transactions"
```

Per-endpoint config with specific rate limits and URL mapping.

### Dynamic (JWT-scoped)

```json
"endpoint": "/v1/my/resource",
"url_pattern": "/internal/v1/tenants/{JWT.tenant_id}/resource"
```

Routes based on JWT claims for tenant/user isolation.

## Checklist

- [ ] Backend added to all 3 settings files (dev, staging, prod)
- [ ] Circuit breaker configured in all 3 settings files
- [ ] Endpoint file created with proper auth and CB
- [ ] Included in krakend.tmpl
- [ ] Egress network policy updated
- [ ] service_routes.json updated
- [ ] Config validation passes
- [ ] API documentation updated
