# Authentication & Authorization Flow

## JWT Lifecycle

```
+----------+     +----------+     +----------+     +-----------+
|  Client  |     | Keycloak |     | Gateway  |     |  Backend  |
+----+-----+     +----+-----+     +----+-----+     +-----+-----+
     |                |                |                   |
     |  1. Login      |                |                   |
     |--------------->|                |                   |
     |  2. JWT token  |                |                   |
     |<---------------|                |                   |
     |                                 |                   |
     |  3. API request + Bearer token  |                   |
     |-------------------------------->|                   |
     |                                 |                   |
     |          4. Fetch JWKS          |                   |
     |          (cached 3600s)         |                   |
     |                 +-------------->| Keycloak          |
     |                 |<--------------| JWKS endpoint     |
     |                                 |                   |
     |          5. Validate JWT        |                   |
     |             - RS256 signature   |                   |
     |             - Issuer match      |                   |
     |             - Audience match    |                   |
     |             - Expiration        |                   |
     |                                 |                   |
     |          6. Check revocation    |                   |
     |             - Bloom filter      |                   |
     |               (jti-based)       |                   |
     |                                 |                   |
     |          7. Check RBAC          |                   |
     |             - realm_access.roles|                   |
     |             - vs endpoint roles |                   |
     |                                 |                   |
     |          8. Propagate claims    |                   |
     |             as headers          |                   |
     |                                 |                   |
     |                                 | 9. Forward with   |
     |                                 |    claim headers  |
     |                                 |------------------>|
     |                                 |                   |
     |          10. Response           |                   |
     |<--------------------------------|<------------------|
```

## JWT Validation Configuration

| Parameter | Value |
|-----------|-------|
| Algorithm | RS256 |
| JWKS Cache | 3600s (1 hour) |
| Failed JWK Key Cooldown | 10s |
| Disable JWK Security | false (configurable) |

### JWKS Endpoints per Environment

| Env | JWKS URL |
|-----|----------|
| Dev | `https://auth.allenty.io/realms/ledgeros/protocol/openid-connect/certs` |
| Staging | `https://auth-staging.revenu.com.br/realms/ledgeros/protocol/openid-connect/certs` |
| Production | `https://auth.revenu.com.br/realms/ledgeros/protocol/openid-connect/certs` |

**Issuer** follows the same domain pattern: `https://{domain}/realms/ledgeros`
**Audience:** `revenu-platform` (all environments)

## Claim Propagation

JWT claims are extracted and propagated as HTTP headers to backends:

| JWT Claim | HTTP Header | Purpose |
|-----------|-------------|---------|
| `sub` | `X-User-ID` | User identity |
| `tenant_id` | `X-Tenant-ID` | Multi-tenancy scoping |
| `realm_access.roles` | `X-Roles` | RBAC enforcement |
| `jti` | `X-JWT-JTI` | Token ID for revocation tracking |
| `subscription_tier` | `X-Subscription-Tier` | Tiered rate limiting and features |

Backends receive these headers and can use them for fine-grained authorization, audit logging, and tenant-scoped data access without needing to re-validate the JWT.

## RBAC Model

Three roles control access across all endpoints:

| Role | Access Level | Typical Operations |
|------|-------------|-------------------|
| `ledger-viewer` | Read-only | GET endpoints |
| `ledger-operator` | Read + write | GET, POST, PUT |
| `ledger-admin` | Full access | GET, POST, PUT, DELETE + admin endpoints |

**Role validation** uses Keycloak's nested role structure:
```json
{
  "roles_key": "realm_access.roles",
  "roles_key_is_nested": true,
  "roles": ["ledger-operator", "ledger-admin"]
}
```

**Pattern across endpoints:**
- `GET` endpoints → viewer + operator + admin
- `POST`/`PUT` endpoints → operator + admin
- `DELETE` endpoints → admin only
- Admin endpoints (`/v1/admin/*`, `/v1/users/*`) → admin only
- Auth endpoints (`/v1/auth/*`) → JWT required, no role restriction
- Health/test endpoints → no auth required

## Token Revocation

Two complementary mechanisms:

### 1. Bloom Filter (Built-in)

```json
{
  "N": 10000000,
  "P": 0.0000001,
  "hash_name": "optimal",
  "TTL": 3600,
  "port": 1234,
  "token_keys": ["jti"]
}
```

- **Capacity:** 10 million tokens
- **False positive rate:** 0.00001%
- **TTL:** 3600s (matches JWT expiry)
- **Key:** `jti` (JWT Token ID)
- **In-memory**, per-instance, synced via port 1234

### 2. Redis-Based (Lua Script)

The `token_revocation.lua` script checks a Redis blacklist for revoked `jti` values. This provides:
- **Distributed** revocation across all gateway instances
- **Real-time** revocation (no bloom filter sync delay)
- **Persistent** across pod restarts

## Dynamic Routing via JWT Claims

Some endpoints use JWT claims to route requests to tenant-scoped or user-scoped backend paths:

```
Gateway Endpoint                     Backend URL
-------------------------------      -------------------------------------------
GET /v1/my/postings           --->   /internal/v1/tenants/{JWT.tenant_id}/transactions
GET /v1/my/balances           --->   /internal/v1/users/{JWT.sub}/balances
GET /v1/my/dashboard          --->   /internal/v1/tenants/{JWT.tenant_id}/summary
                                     + /internal/v1/tenants/{JWT.tenant_id}/payment-summary
```

KrakenD CE natively supports `{JWT.claim}` interpolation in `url_pattern`, enabling tenant isolation without custom middleware. The gateway resolves the claim value from the validated JWT and injects it into the backend URL before proxying.

## OAuth2 Client Credentials

The gateway can also act as an OAuth2 client (machine-to-machine):

```json
{
  "client_id": "krakend-gateway",
  "token_url": "{keycloak}/protocol/openid-connect/token",
  "scopes": "openid",
  "audience": ["revenu-platform"]
}
```

Used for backend-to-backend calls where the gateway needs its own identity token (e.g., service mesh scenarios).
