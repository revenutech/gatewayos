# LedgerOS Routes

Backend: `ledgeros:8081` (HTTP) / `ledgeros:9081` (gRPC via Envoy transcoder)

LedgerOS is the core accounting engine. It exposes three route groups through the gateway: HTTP, gRPC, and dynamic (JWT claim-scoped).

## HTTP Endpoints

### POST /v1/postings

Creates a new posting (transaction).

- **Backend path:** `/v1/transactions` (note: URL mapping differs from gateway path)
- **Roles:** ledger-operator, ledger-admin
- **Rate limit:** postings_write — 1,000 global / 100 per tenant per minute
- **Circuit breaker:** cb-ledgeros-posting (5 errors / 60s / 10s timeout)
- **Encoding:** json

### GET /v1/postings/{id}

Retrieves a specific posting by ID.

- **Backend path:** `/v1/transactions/{id}`
- **Roles:** ledger-viewer, ledger-operator, ledger-admin
- **Rate limit:** balances_read — 5,000 global / 500 per tenant per minute
- **Circuit breaker:** cb-ledgeros-posting

### GET /v1/balances/{id}

Retrieves balance for an account.

- **Backend path:** `/v1/balances/{id}` (1:1 mapping)
- **Roles:** ledger-viewer, ledger-operator, ledger-admin
- **Rate limit:** balances_read
- **Circuit breaker:** cb-ledgeros-posting

### POST /v1/settlements

Creates a settlement batch.

- **Backend path:** `/v1/settlements`
- **Roles:** ledger-operator, ledger-admin
- **Circuit breaker:** cb-ledgeros-posting

### POST /v1/reconciliation/jobs

Starts a reconciliation job.

- **Backend path:** `/v1/reconciliation/jobs`
- **Roles:** ledger-operator, ledger-admin
- **Circuit breaker:** cb-ledgeros-posting

## gRPC Endpoints (via Envoy Transcoder)

Mirror the HTTP endpoints under `/grpc/v1/*` prefix. Requests go through the Envoy sidecar (:8085) which transcodes REST→gRPC to LedgerOS :9081.

| Gateway Path | gRPC Service | Method |
|-------------|-------------|--------|
| POST `/grpc/v1/postings` | PostingService | CreatePosting |
| GET `/grpc/v1/postings/{id}` | PostingService | GetPosting |
| GET `/grpc/v1/balances/{id}` | BalanceService | GetBalance |
| POST `/grpc/v1/settlements` | SettlementService | CreateSettlement |
| POST `/grpc/v1/reconciliation/jobs` | ReconciliationService | CreateJob |

- **Circuit breaker:** cb-ledgeros-grpc (5 errors / 60s / 10s timeout)
- **Rate limits:** Same as HTTP equivalents

## Dynamic Routing Endpoints

Use JWT claims to route to tenant-scoped or user-scoped internal backend paths. The gateway resolves `{JWT.tenant_id}` and `{JWT.sub}` from the validated token.

### GET /v1/my/postings

- **Backend path:** `/internal/v1/tenants/{JWT.tenant_id}/transactions`
- **Roles:** viewer, operator, admin
- **Rate limit:** balances_read
- Scoped to the authenticated user's tenant

### GET /v1/my/balances

- **Backend path:** `/internal/v1/users/{JWT.sub}/balances`
- **Roles:** viewer, operator, admin
- **Rate limit:** balances_read
- Scoped to the authenticated user

### GET /v1/my/dashboard

Aggregated endpoint querying 2 backends:
- LedgerOS: `/internal/v1/tenants/{JWT.tenant_id}/summary` (group: `ledger`)
- Paymentos: `/internal/v1/tenants/{JWT.tenant_id}/payment-summary` (group: `payments`)

Response is merged into `{ "ledger": {...}, "payments": {...} }`.

## URL Mapping

Note that gateway paths do not always match backend paths:

| Gateway | Backend | Reason |
|---------|---------|--------|
| `/v1/postings` | `/v1/transactions` | Domain terminology: "posting" is the external term, "transaction" is internal |
| `/v1/my/*` | `/internal/v1/tenants/{tenant_id}/*` | Public path hides internal tenant routing |
