# Dashboard Routes

Dashboard endpoints aggregate data from multiple backends into single responses using KrakenD's multi-backend composition.

## GET /v1/dashboard/overview

Aggregated platform overview combining data from 4 backends.

| Backend | URL | Response Group | Timeout | Extra |
|---------|-----|---------------|---------|-------|
| ledgeros:8081 | /v1/dashboard/ledger-summary | `ledger` | 3s | HTTP cache (shared) |
| paymentos:8082 | /v1/dashboard/payment-summary | `payments` | 3s | — |
| atmos:8088 | /v1/dashboard/automation-summary | `automation` | 3s | is_collection: true |
| accountos:8093 | /v1/dashboard/account-summary | `accounts` | 3s | — |

- **Endpoint timeout:** 5s
- **Concurrent calls:** 4 (all backends queried in parallel)
- **Roles:** ledger-viewer, ledger-operator, ledger-admin

Response structure:
```json
{
  "ledger": { ... },
  "payments": { ... },
  "automation": [ ... ],
  "accounts": { ... }
}
```

The `automation` group uses `is_collection: true` because AtmOS returns an array.

## GET /v1/dashboard/health

Aggregated health check across 5 backends.

| Backend | URL | Response Group |
|---------|-----|---------------|
| ledgeros:8081 | /health | `ledgeros` |
| paymentos:8082 | /health | `paymentos` |
| atmos:8088 | /health | `atmos` |
| identityos:8091 | /health | `identityos` |
| accountos:8093 | /health | `accountos` |

- **Endpoint timeout:** 3s
- **Concurrent calls:** 5
- **Roles:** ledger-admin **only**

Response structure:
```json
{
  "ledgeros": { "status": "ok" },
  "paymentos": { "status": "ok" },
  "atmos": { "status": "ok" },
  "identityos": { "status": "ok" },
  "accountos": { "status": "ok" }
}
```

## Composition Pattern

KrakenD CE natively supports multiple backends per endpoint. Each backend response is placed under its `group` key. If a backend fails or times out, its group is omitted from the response (partial response). The endpoint-level timeout (5s or 3s) acts as a deadline for the entire aggregation.
