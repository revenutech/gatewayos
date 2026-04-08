# AtmOS Routes

Backend: `atmos:8088`

AtmOS handles ATM and cash management operations.

## Endpoints

| Path | Method | Roles | Description |
|------|--------|-------|-------------|
| `/v1/atm/{path}` | POST | operator, admin | ATM operations |
| `/v1/atm/{path}` | GET | viewer, operator, admin | Query ATM data |

## Configuration

- **Circuit breaker:** cb-atmos (10 errors / 120s / 30s timeout)
- **Encoding:** no-op (passthrough)
- **Headers:** X-User-ID, X-Tenant-ID, X-Roles, X-Correlation-ID, Content-Type

## Circuit Breaker Rationale

AtmOS has the most lenient CB config:
- **10 max errors** (vs 5 standard) — ATM operations may have intermittent failures
- **120s interval** (vs 60s) — wider error window
- **30s timeout** (vs 10s) — longer recovery for hardware-dependent operations
