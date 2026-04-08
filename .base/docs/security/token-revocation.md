# Token Revocation

Two complementary mechanisms for revoking JWT tokens before expiry.

## 1. Bloom Filter (Built-in)

Native KrakenD `auth/revoker` using a probabilistic data structure.

```json
"auth/revoker": {
  "N": 10000000,
  "P": 0.0000001,
  "hash_name": "optimal",
  "TTL": 3600,
  "port": 1234,
  "token_keys": ["jti"]
}
```

| Parameter | Value | Description |
|-----------|-------|-------------|
| N | 10,000,000 | Max tokens the filter can hold |
| P | 0.0000001 | False positive rate (0.00001%) |
| hash_name | optimal | Hash function selection |
| TTL | 3600s | Token entry lifetime (matches JWT expiry) |
| port | 1234 | Sync port between instances |
| token_keys | ["jti"] | JWT claim used as revocation key |

**Characteristics:**
- In-memory, per-instance
- Synced across instances via port 1234
- Very fast lookup (O(1))
- Space-efficient (~10MB for 10M tokens at this FPR)
- Cannot remove entries (TTL-based expiry only)

## 2. Redis-Based (Lua Script)

Custom `token_revocation.lua` checks a Redis blacklist.

- **Script:** `krakend/partials/lua/token_revocation.lua`
- **Hook:** pre_proxy
- **Key:** JTI from `X-JWT-JTI` header

**Characteristics:**
- Distributed across all gateway instances
- Real-time revocation (no sync delay)
- Persistent across pod restarts
- Can explicitly remove entries
- Slightly slower than Bloom filter (Redis network round-trip)

## Combined Flow

```
Request with JWT
     |
     v
[1] JWT Validation (RS256)
     |
     v
[2] Bloom Filter Check (in-memory, ~microseconds)
     |-- Revoked? --> 401 Unauthorized
     |
     v
[3] Redis Blacklist Check (network, ~milliseconds)
     |-- Revoked? --> 401 Unauthorized
     |
     v
[4] Continue to RBAC / rate limiting / backend
```

## Revocation Process

To revoke a token:

1. **Add to Redis blacklist:** Set key `revoked:jti:{token_jti}` with TTL matching token expiry
2. **Add to Bloom filter:** Push to the revoker API on port 1234
3. Both mechanisms will reject the token on next request

## Capacity Planning

- **Bloom filter:** 10M tokens at 0.00001% FPR uses ~10MB memory
- **Redis:** Each revoked token key is ~50 bytes + TTL overhead
- **TTL alignment:** Both use 3600s (1 hour), matching typical JWT expiry
