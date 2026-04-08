# Lua Scripts Reference

17 Lua scripts in `krakend/partials/lua/` implement enterprise-grade features without KrakenD Enterprise license.

## Script Inventory

| # | Script | Hook | Redis | ISO Ref | Purpose |
|---|--------|------|-------|---------|---------|
| 1 | hello.lua | — | No | — | Test/hello world |
| 2 | test_minimal.lua | pre + post | No | — | Integration test middleware |
| 3 | test_middleware.lua | — | No | — | Middleware testing |
| 4 | access_log.lua | post_proxy | No | A.8.15 | Structured access logging |
| 5 | audit_evidence.lua | post_proxy | No | A.5.28, A.8.15 | Audit evidence collection |
| 6 | api_key_auth.lua | pre_proxy | No | A.8.5 | API key authentication |
| 7 | redis_rate_limit.lua | pre_proxy | Yes | A.8.6 | Distributed rate limiting |
| 8 | tiered_rate_limit.lua | pre_proxy | Yes | A.8.6 | Subscription-tier rate limiting |
| 9 | response_cache.lua | pre + post | Yes | — | Redis-based response caching |
| 10 | token_revocation.lua | pre_proxy | Yes | A.8.5 | Token blacklist check |
| 11 | circuit_breaker_custom.lua | pre + post | Yes | A.8.14 | Stateful CB (closed/open/half-open) |
| 12 | web_filter.lua | pre_proxy | No | A.8.23 | SSRF prevention, URL blocklist |
| 13 | security_policies.lua | pre_proxy | No | A.5.1 | Security policy enforcement |
| 14 | json_schema_validator.lua | pre_proxy | No | A.8.25 | JSON request body validation |
| 15 | dlp.lua | post_proxy | No | A.8.12, A.5.34 | Data leakage prevention, PII masking |
| 16 | classification_labels.lua | post_proxy | No | A.5.12 | Data classification labeling |
| 17 | business_metrics.lua | post_proxy | Yes | — | Business event metrics |

## Hook Points

- **pre_proxy:** Executes before the request is forwarded to the backend. Used for auth, rate limiting, validation, filtering.
- **post_proxy:** Executes after the backend response is received. Used for logging, DLP, caching, metrics.

## Redis-Dependent Scripts

6 scripts require Redis connectivity:
- redis_rate_limit.lua
- tiered_rate_limit.lua
- response_cache.lua
- token_revocation.lua
- circuit_breaker_custom.lua
- business_metrics.lua

Redis configuration is passed via `extra_config.dynamic_config`:
```json
"extra_config": {
  "dynamic_config": {
    "redis_host": "{{ .redis.host }}",
    "redis_port": "{{ .redis.port }}"
  }
}
```

## Script Details

### api_key_auth.lua

Validates API keys from the `X-API-Key` header against a pipe-delimited registry:

```
key_id:key_value:tenant:roles:tier:active|key_id:key_value:...
```

### redis_rate_limit.lua

Distributed rate limiting using Redis INCR with TTL. Sliding window of 60 seconds. Checks both global and per-tenant limits.

### tiered_rate_limit.lua

Extends rate limiting with subscription tiers. Reads `X-Subscription-Tier` header to apply tier-specific limits from Redis.

### circuit_breaker_custom.lua

Three-state circuit breaker (closed → open → half-open):
- **Closed:** Normal operation, counting errors
- **Open:** All requests rejected immediately
- **Half-open:** Allows up to 3 probe requests to test recovery

State is stored in Redis, enabling cross-instance coordination.

### response_cache.lua

Two-phase caching:
- **pre_proxy:** Check Redis for cached response (cache hit skips backend)
- **post_proxy:** Store successful response in Redis with configurable TTL (default 60s)

### dlp.lua

Scans response bodies for PII patterns (CPF, CNPJ, email, phone) and masks sensitive data before returning to client.

### web_filter.lua

Validates request URLs against blocklists to prevent SSRF attacks. Blocks internal IPs, metadata endpoints, and known malicious patterns.
