---
title: "Runbook: Token Revocation"
iso_ref: "A.5.17 (Authentication information), A.5.18 (Access rights)"
---

# Token Revocation

## Revoke Single Token (by JTI)
```bash
redis-cli -h redis SADD revoked_tokens "<jti>"
redis-cli -h redis EXPIRE revoked_tokens 3600  # Match token TTL
```

## Revoke All Tokens for a User
```bash
redis-cli -h redis SADD revoked_users "<user_id>"
# No TTL — remains until manually removed
```

## Revoke All Tokens for a Tenant (Emergency)
```bash
redis-cli -h redis SADD revoked_tenants "<tenant_id>"
# No TTL — remains until manually removed
# WARNING: This blocks ALL users in the tenant
```

## Undo Revocation
```bash
# Remove single token
redis-cli -h redis SREM revoked_tokens "<jti>"

# Remove user revocation
redis-cli -h redis SREM revoked_users "<user_id>"

# Remove tenant revocation
redis-cli -h redis SREM revoked_tenants "<tenant_id>"
```

## Verify
```bash
# Check if token is revoked
redis-cli -h redis SISMEMBER revoked_tokens "<jti>"
# Returns 1 if revoked, 0 if not

# Count revoked items
redis-cli -h redis SCARD revoked_tokens
redis-cli -h redis SCARD revoked_users
redis-cli -h redis SCARD revoked_tenants
```
