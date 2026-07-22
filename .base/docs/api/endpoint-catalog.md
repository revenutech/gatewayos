# Endpoint Catalog

Master reference of all gateway endpoints.

## Health & Infrastructure

| Path | Method | Backend | Auth | Roles | Rate Limit | CB | Encoding |
|------|--------|---------|------|-------|------------|----|---------|
| `/__health` | GET | KrakenD internal | None | — | — | — | — |
| `/__ready` | GET | ledgeros:8081/health | None | — | — | — | no-op |
| `/__metrics` | GET | KrakenD internal | None | — | — | — | — |

## LedgerOS — HTTP (`ledgeros:8081`)

| Path | Method | Backend Path | Roles | Rate Limit | CB |
|------|--------|-------------|-------|------------|-----|
| `/v1/postings` | POST | /v1/transactions | operator, admin | postings_write (1000g/100t) | cb-ledgeros-posting |
| `/v1/postings/{id}` | GET | /v1/transactions/{id} | viewer, operator, admin | balances_read (5000g/500t) | cb-ledgeros-posting |
| `/v1/balances/{id}` | GET | /v1/balances/{id} | viewer, operator, admin | balances_read | cb-ledgeros-posting |
| `/v1/settlements` | POST | /v1/settlements | operator, admin | — | cb-ledgeros-posting |
| `/v1/reconciliation/jobs` | POST | /v1/reconciliation/jobs | operator, admin | — | cb-ledgeros-posting |

## LedgerOS — gRPC via Envoy (`envoy:8085`)

| Path | Method | Backend Path | Roles | Rate Limit | CB |
|------|--------|-------------|-------|------------|-----|
| `/grpc/v1/postings` | POST | /grpc/v1/postings | operator, admin | postings_write | cb-ledgeros-grpc |
| `/grpc/v1/postings/{id}` | GET | /grpc/v1/postings/{id} | viewer, operator, admin | balances_read | cb-ledgeros-grpc |
| `/grpc/v1/balances/{id}` | GET | /grpc/v1/balances/{id} | viewer, operator, admin | balances_read | cb-ledgeros-grpc |
| `/grpc/v1/settlements` | POST | /grpc/v1/settlements | operator, admin | — | cb-ledgeros-grpc |
| `/grpc/v1/reconciliation/jobs` | POST | /grpc/v1/reconciliation/jobs | operator, admin | — | cb-ledgeros-grpc |

## LedgerOS — Dynamic Routing (JWT claim-based)

| Path | Method | Backend Path | Roles | Rate Limit | CB |
|------|--------|-------------|-------|------------|-----|
| `/v1/my/postings` | GET | /internal/v1/tenants/{JWT.tenant_id}/transactions | viewer, operator, admin | balances_read | cb-ledgeros-posting |
| `/v1/my/balances` | GET | /internal/v1/users/{JWT.sub}/balances | viewer, operator, admin | balances_read | cb-ledgeros-posting |
| `/v1/my/dashboard` | GET | Aggregated: ledgeros + paymentos (tenant-scoped) | viewer, operator, admin | — | cb-ledgeros-posting, cb-paymentos |

## Paymentos (`paymentos:8082`)

| Path | Method | Roles | CB | Encoding |
|------|--------|-------|-----|---------|
| `/v1/pix/{path}` | POST | operator, admin | cb-paymentos | no-op |
| `/v1/pix/{path}` | GET | viewer, operator, admin | cb-paymentos | no-op |
| `/v1/ted/{path}` | POST | operator, admin | cb-paymentos | no-op |
| `/v1/boleto/{path}` | POST | operator, admin | cb-paymentos | no-op |

## IdentityOS (`identityos:8091`)

| Path | Method | Roles | CB | Encoding |
|------|--------|-------|-----|---------|
| `/v1/auth/{path}` | POST | JWT only (no role) | cb-identityos | no-op |
| `/v1/users/{path}` | GET | admin | cb-identityos | no-op |

## AtmOS (`atmos:8088`)

| Path | Method | Roles | CB | Encoding |
|------|--------|-------|-----|---------|
| `/v1/atm/{path}` | POST | operator, admin | cb-atmos | no-op |
| `/v1/atm/{path}` | GET | viewer, operator, admin | cb-atmos | no-op |

## Admin (`ledgeros:8081`)

| Path | Method | Roles | CB | Encoding |
|------|--------|-------|-----|---------|
| `/v1/admin/{path}` | GET | admin | cb-ledgeros-posting | no-op |
| `/v1/admin/{path}` | POST | admin | cb-ledgeros-posting | no-op |

## OnboardOS (`onboardos:8092`)

21 route prefixes, each with 4 HTTP methods. All use `no-op` encoding and `cb-onboardos`.

| Prefix | GET Roles | POST Roles | PUT Roles | DELETE Roles |
|--------|-----------|-----------|-----------|-------------|
| `/v1/onboarding/{path}` | viewer+ | operator+ | operator+ | admin |
| `/v1/kyc/{path}` | viewer+ | operator+ | operator+ | admin |
| `/v1/dd/{path}` | viewer+ | operator+ | operator+ | admin |
| `/v1/journeys/{path}` | viewer+ | operator+ | operator+ | admin |
| `/v1/documents/{path}` | viewer+ | operator+ | operator+ | admin |
| `/v1/leads/{path}` | viewer+ | operator+ | operator+ | admin |
| `/v1/risk/{path}` | viewer+ | operator+ | operator+ | admin |
| `/v1/rio/{path}` | viewer+ | operator+ | operator+ | admin |
| `/v1/aml/{path}` | viewer+ | operator+ | operator+ | admin |
| `/v1/screenings/{path}` | viewer+ | operator+ | operator+ | admin |
| `/v1/cases/{path}` | viewer+ | operator+ | operator+ | admin |
| `/v1/policies/{path}` | viewer+ | operator+ | operator+ | admin |
| `/v1/reviews/{path}` | viewer+ | operator+ | operator+ | admin |
| `/v1/offboarding/{path}` | viewer+ | operator+ | operator+ | admin |
| `/v1/mdm/{path}` | viewer+ | operator+ | operator+ | admin |
| `/v1/audit/{path}` | viewer+ | operator+ | operator+ | admin |
| `/v1/sessions/{path}` | viewer+ | operator+ | operator+ | admin |
| `/v1/milestones/{path}` | viewer+ | operator+ | operator+ | admin |
| `/v1/notifications/{path}` | viewer+ | operator+ | operator+ | admin |
| `/v1/business-entities/{path}` | viewer+ | operator+ | operator+ | admin |
| `/v1/cnpj/{path}` | viewer+ | operator+ | operator+ | admin |

**Total: ~84 effective endpoints** (21 prefixes x 4 methods)

## AccountOS (`accountos:8093`)

| Path | Method | Roles | CB | Encoding |
|------|--------|-------|-----|---------|
| `/v1/accounts/{path}` | POST | operator, admin | cb-accountos | no-op |
| `/v1/accounts/{path}` | GET | viewer, operator, admin | cb-accountos | no-op |
| `/v1/accounts/{path}` | PUT | operator, admin | cb-accountos | no-op |

## FinanceOS (`financeos:8095`)

| Path | Method | Roles | CB | Encoding |
|------|--------|-------|-----|---------|
| `/v1/finance/{path}` | POST | operator, admin | cb-financeos | no-op |
| `/v1/finance/{path}` | GET | viewer, operator, admin | cb-financeos | no-op |

## Dashboard — Aggregated Multi-Backend

| Path | Method | Backends | Concurrent | Timeout | Roles |
|------|--------|----------|-----------|---------|-------|
| `/v1/dashboard/overview` | GET | ledgeros, paymentos, atmos, accountos | 4 | 5s | viewer, operator, admin |
| `/v1/dashboard/health` | GET | ledgeros, paymentos, atmos, identityos, accountos | 5 | 3s | admin |

## Test Endpoints

| Path | Method | Auth | Purpose |
|------|--------|------|---------|
| `/v1/test/echo` | GET | None | Lua middleware integration test |
| `/v1/test/validate` | POST | None | Lua schema validation test |

## Summary

| Module | Endpoints | Backend | Auth Pattern |
|--------|-----------|---------|-------------|
| LedgerOS HTTP | 5 | ledgeros:8081 | JWT + RBAC + rate limit |
| LedgerOS gRPC | 5 | envoy:8085 | JWT + RBAC + rate limit |
| LedgerOS Dynamic | 3 | ledgeros:8081 | JWT + RBAC (claim-based routing) |
| Paymentos | 4 | paymentos:8082 | JWT + RBAC |
| IdentityOS | 2 | identityos:8091 | JWT (+ admin-only for /users) |
| AtmOS | 2 | atmos:8088 | JWT + RBAC |
| Admin | 2 | ledgeros:8081 | JWT + admin-only |
| OnboardOS | ~84 | onboardos:8092 | JWT + RBAC |
| AccountOS | 3 | accountos:8093 | JWT + RBAC |
| FinanceOS | 2 | financeos:8095 | JWT + RBAC |
| Dashboard | 2 | multi-backend | JWT + RBAC |
| Test | 2 | ledgeros:8081 | None |
| Health | 3 | internal/proxy | None |
| **Total** | **~119** | | |
