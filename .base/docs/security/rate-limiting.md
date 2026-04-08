# Rate Limiting

Three rate limiting strategies, from simple to advanced.

## 1. Native KrakenD Rate Limiter

Built-in KrakenD `qos/ratelimit/router`. Per-tenant via `X-Tenant-ID` header.

```json
"qos/ratelimit/router": {
  "max_rate": 5000,
  "client_max_rate": 500,
  "strategy": "header",
  "key": "X-Tenant-ID",
  "every": "1m"
}
```

- **Strategy:** `header` — uses X-Tenant-ID for client identification
- **Window:** 1 minute (sliding)
- **Scope:** Per-instance (not distributed)

### Limits by Endpoint Group

| Group | Global Max/min | Tenant Max/min | Applied To |
|-------|---------------|----------------|-----------|
| Default | 5,000 (dev/stg) / 10,000 (prod) | 500 (dev/stg) / 1,000 (prod) | Most endpoints |
| postings_write | 1,000 | 100 | POST /v1/postings, POST /grpc/v1/postings |
| balances_read | 5,000 | 500 | GET /v1/balances/*, GET /v1/postings/*, /v1/my/* |

## 2. Redis Distributed Rate Limiter

Lua-based (`redis_rate_limit.lua`) for cross-instance coordination.

- **Window:** 60 seconds (sliding)
- **Backend:** Redis INCR with TTL
- **Config:** global_max, tenant_max from settings

Useful when running multiple gateway replicas (K8s HPA) — ensures the global limit is respected across all instances.

## 3. Tiered Rate Limiter

Lua-based (`tiered_rate_limit.lua`) for subscription-based limits.

- Reads `X-Subscription-Tier` header (propagated from JWT `subscription_tier` claim)
- Applies tier-specific limits from Redis configuration
- Enables premium/enterprise customers to have higher rate limits

## Limits by Environment

| Setting | Dev | Staging | Production |
|---------|-----|---------|------------|
| Default global | 5,000/min | 5,000/min | 10,000/min |
| Default tenant | 500/min | 500/min | 1,000/min |
| Postings global | 1,000/min | 1,000/min | 1,000/min |
| Postings tenant | 100/min | 100/min | 100/min |

## Rate Limit Response

When a client exceeds the limit:
- HTTP 429 Too Many Requests
- `Retry-After` header included
- Tracked per `X-Tenant-ID` header value

## Defense in Depth

Rate limiting is applied at multiple layers:

1. **Nginx Ingress** — 100 req/s per IP (burst 200) at the ingress controller level
2. **KrakenD Native** — Per-tenant limits at the gateway level
3. **Redis Distributed** — Cross-instance coordination for accurate global limits
4. **Tiered** — Subscription-based differentiation
