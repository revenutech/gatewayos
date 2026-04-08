# CORS Policy

Cross-Origin Resource Sharing configuration per environment.

## Origins

| Environment | Allowed Origins |
|-------------|----------------|
| Dev | `http://localhost:3000`, `http://localhost:8081` |
| Staging | `https://staging.revenu.com.br` |
| Production | `https://app.revenu.com.br` |

## Shared Configuration

| Setting | Value |
|---------|-------|
| Methods | GET, POST, PUT, DELETE, PATCH, OPTIONS |
| Request Headers | Authorization, Content-Type, X-Correlation-ID |
| Exposed Headers | X-Request-ID, X-Correlation-ID |
| Max Age | 12h |
| Allow Credentials | true |

## Template

```json
"security/cors": {
  "allow_origins": {{ marshal .cors.allow_origins }},
  "allow_methods": {{ marshal .cors.allow_methods }},
  "allow_headers": {{ marshal .cors.allow_headers }},
  "expose_headers": ["X-Request-ID", "X-Correlation-ID"],
  "max_age": "12h",
  "allow_credentials": true
}
```

## Notes

- CORS is configured at the global level in `krakend.tmpl`, applying to all endpoints
- `allow_credentials: true` is required for JWT Bearer token authentication from browsers
- `X-Correlation-ID` is both an allowed request header and an exposed response header for end-to-end tracing
- Preflight (OPTIONS) responses are cached for 12 hours to minimize preflight requests
