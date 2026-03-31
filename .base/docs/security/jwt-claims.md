# JWT Validation & Claims

## Validation Configuration

| Parameter | Value |
|-----------|-------|
| Algorithm | RS256 (RSA Signature with SHA-256) |
| Cache | Enabled, 3600s duration |
| Failed JWK Key Cooldown | 10s |
| Disable JWK Security | false (configurable per env) |
| Audience | `revenu-platform` |

## JWKS Endpoints

| Environment | JWKS URL | Issuer |
|-------------|----------|--------|
| Dev | `https://auth.allenty.io/realms/ledgeros/protocol/openid-connect/certs` | `https://auth.allenty.io/realms/ledgeros` |
| Staging | `https://auth-staging.revenu.com.br/realms/ledgeros/protocol/openid-connect/certs` | `https://auth-staging.revenu.com.br/realms/ledgeros` |
| Production | `https://auth.revenu.com.br/realms/ledgeros/protocol/openid-connect/certs` | `https://auth.revenu.com.br/realms/ledgeros` |

## Claims Propagation

JWT claims are extracted and forwarded to backends as HTTP headers:

| JWT Claim | HTTP Header | Type | Purpose |
|-----------|-------------|------|---------|
| `sub` | `X-User-ID` | String (UUID) | Unique user identity |
| `tenant_id` | `X-Tenant-ID` | String | Multi-tenancy isolation |
| `realm_access.roles` | `X-Roles` | String (comma-separated) | RBAC role list |
| `jti` | `X-JWT-JTI` | String (UUID) | Token ID for revocation |
| `subscription_tier` | `X-Subscription-Tier` | String | Tiered features and rate limits |

## Validation Flow

1. **Extract:** Bearer token from Authorization header
2. **Fetch JWKS:** Download public keys from Keycloak (cached for 3600s)
3. **Verify signature:** RS256 with matching key from JWKS
4. **Check issuer:** Must match configured issuer for environment
5. **Check audience:** Must include `revenu-platform`
6. **Check expiration:** Token must not be expired
7. **Check revocation:** JTI checked against Bloom filter (10M capacity)
8. **Extract claims:** Propagate sub, tenant_id, roles, jti, subscription_tier as headers
9. **RBAC check:** Verify realm_access.roles includes required role for endpoint

## Dynamic Routing

Some endpoints use JWT claims to construct backend paths:

```
GET /v1/my/postings
  → Backend: /internal/v1/tenants/{JWT.tenant_id}/transactions

GET /v1/my/balances
  → Backend: /internal/v1/users/{JWT.sub}/balances
```

KrakenD resolves `{JWT.claim}` placeholders from the validated token before proxying. This enables tenant/user isolation without custom middleware.

## JWKS Cache Behavior

- Keys are cached for 3600s (1 hour)
- On validation failure, the gateway waits 10s (`failed_jwk_key_cooldown`) before retrying JWKS fetch
- Network policy allows egress to Keycloak on ports 8443/8080
