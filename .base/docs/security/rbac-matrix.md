# RBAC Matrix

## Roles

| Role | Level | Description |
|------|-------|-------------|
| `ledger-viewer` | Read-only | Can view data across all modules |
| `ledger-operator` | Read + Write | Can create and update records |
| `ledger-admin` | Full access | All operations including delete and admin |

## Access Matrix

Legend: **R** = Read (GET), **W** = Write (POST), **U** = Update (PUT), **D** = Delete

### LedgerOS

| Endpoint | viewer | operator | admin |
|----------|--------|----------|-------|
| GET /v1/postings/{id} | R | R | R |
| POST /v1/postings | — | W | W |
| GET /v1/balances/{id} | R | R | R |
| POST /v1/settlements | — | W | W |
| POST /v1/reconciliation/jobs | — | W | W |
| GET /v1/my/postings | R | R | R |
| GET /v1/my/balances | R | R | R |
| GET /v1/my/dashboard | R | R | R |

### LedgerOS gRPC (same permissions as HTTP)

| Endpoint | viewer | operator | admin |
|----------|--------|----------|-------|
| /grpc/v1/* | Same as /v1/* equivalent | | |

### Paymentos

| Endpoint | viewer | operator | admin |
|----------|--------|----------|-------|
| GET /v1/pix/{path} | R | R | R |
| POST /v1/pix/{path} | — | W | W |
| POST /v1/ted/{path} | — | W | W |
| POST /v1/boleto/{path} | — | W | W |

### IdentityOS

| Endpoint | viewer | operator | admin |
|----------|--------|----------|-------|
| POST /v1/auth/{path} | JWT only | JWT only | JWT only |
| GET /v1/users/{path} | — | — | R |

### AtmOS

| Endpoint | viewer | operator | admin |
|----------|--------|----------|-------|
| GET /v1/atm/{path} | R | R | R |
| POST /v1/atm/{path} | — | W | W |

### Admin

| Endpoint | viewer | operator | admin |
|----------|--------|----------|-------|
| GET /v1/admin/{path} | — | — | R |
| POST /v1/admin/{path} | — | — | W |

### OnboardOS (21 prefixes, same pattern each)

| Method | viewer | operator | admin |
|--------|--------|----------|-------|
| GET /v1/{prefix}/{path} | R | R | R |
| POST /v1/{prefix}/{path} | — | W | W |
| PUT /v1/{prefix}/{path} | — | U | U |
| DELETE /v1/{prefix}/{path} | — | — | D |

### AccountOS

| Endpoint | viewer | operator | admin |
|----------|--------|----------|-------|
| GET /v1/accounts/{path} | R | R | R |
| POST /v1/accounts/{path} | — | W | W |
| PUT /v1/accounts/{path} | — | U | U |

### FinanceOS

| Endpoint | viewer | operator | admin |
|----------|--------|----------|-------|
| GET /v1/finance/{path} | R | R | R |
| POST /v1/finance/{path} | — | W | W |

### Dashboard

| Endpoint | viewer | operator | admin |
|----------|--------|----------|-------|
| GET /v1/dashboard/overview | R | R | R |
| GET /v1/dashboard/health | — | — | R |

### No Auth Required

| Endpoint | Access |
|----------|--------|
| GET /__health | Public |
| GET /__ready | Public |
| GET /v1/test/echo | Public |
| POST /v1/test/validate | Public |

## Pattern Summary

| HTTP Method | Minimum Role |
|-------------|-------------|
| GET | ledger-viewer |
| POST | ledger-operator |
| PUT | ledger-operator |
| DELETE | ledger-admin |
| Admin endpoints | ledger-admin (all methods) |
| Auth endpoints | JWT only (no role) |
| Health/test | None |
