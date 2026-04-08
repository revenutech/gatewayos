# Admin Routes

Backend: `ledgeros:8081`

Admin endpoints provide administrative access to the LedgerOS core engine.

## Endpoints

| Path | Method | Roles | Description |
|------|--------|-------|-------------|
| `/v1/admin/{path}` | GET | admin | Read admin data (config, system status, etc.) |
| `/v1/admin/{path}` | POST | admin | Admin operations (migrations, bulk ops, etc.) |

## Configuration

- **Circuit breaker:** cb-ledgeros-posting (shared with core LedgerOS endpoints)
- **Encoding:** no-op (passthrough)
- **Headers:** X-User-ID, X-Tenant-ID, X-Roles, X-Correlation-ID, Content-Type

## Access Control

Both GET and POST are restricted to `ledger-admin` role only. This is the most restrictive access pattern in the gateway — no viewer or operator access is permitted.
