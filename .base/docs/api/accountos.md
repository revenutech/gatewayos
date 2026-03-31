# AccountOS Routes

Backend: `accountos:8093`

AccountOS handles account management operations.

## Endpoints

| Path | Method | Roles | Description |
|------|--------|-------|-------------|
| `/v1/accounts/{path}` | POST | operator, admin | Create accounts |
| `/v1/accounts/{path}` | GET | viewer, operator, admin | Query accounts |
| `/v1/accounts/{path}` | PUT | operator, admin | Update accounts |

## Configuration

- **Circuit breaker:** cb-accountos (5 errors / 60s / 10s timeout)
- **Encoding:** no-op (passthrough)
- **Headers:** X-User-ID, X-Tenant-ID, X-Roles, X-Correlation-ID, Content-Type, X-Subscription-Tier

## Wildcard Routing

Uses `{path}` wildcard, so all sub-routes are forwarded 1:1:

```
POST /v1/accounts/create          --> POST accountos:8093/v1/accounts/create
GET  /v1/accounts/123/details     --> GET  accountos:8093/v1/accounts/123/details
PUT  /v1/accounts/123/status      --> PUT  accountos:8093/v1/accounts/123/status
```
