---
title: "Runbook: Redis Authentication Setup"
iso_ref: "A.8.5 (Secure authentication), A.8.20 (Networks security)"
---

# Redis Authentication Setup

> **GAP-08:** Redis currently relies on NetworkPolicy for access control.
> This runbook documents the procedure to enable Redis AUTH for defense-in-depth.

## Enable Redis AUTH

### 1. Create Redis Secret
```bash
# Generate a strong password
REDIS_PASSWORD=$(openssl rand -base64 32)

# Create K8s secret
kubectl create secret generic redis-auth \
  --from-literal=redis-password="$REDIS_PASSWORD"
```

### 2. Configure Redis
Add to Redis deployment/StatefulSet:
```yaml
args: ["--requirepass", "$(REDIS_PASSWORD)"]
env:
  - name: REDIS_PASSWORD
    valueFrom:
      secretKeyRef:
        name: redis-auth
        key: redis-password
```

### 3. Update KrakenD Settings
Add to each environment settings file (`settings/{dev,staging,prod}.json`):
```json
"redis": {
  "host": "redis",
  "port": "6379",
  "password": "${REDIS_PASSWORD}"
}
```

### 4. Update Lua Scripts
All Lua scripts using Redis need AUTH after connect:
```lua
redis:call("AUTH", dynamic_config("redis_password"))
```

Affected scripts:
- `lua/redis_rate_limit.lua`
- `lua/tiered_rate_limit.lua`
- `lua/token_revocation.lua`
- `lua/circuit_breaker_custom.lua`
- `lua/business_metrics.lua`
- `lua/response_cache.lua`

### 5. Verify
```bash
# Test auth
redis-cli -h redis -a "$REDIS_PASSWORD" PING
# Expected: PONG

# Test without auth (should fail)
redis-cli -h redis PING
# Expected: NOAUTH Authentication required
```

## Status
- **Current:** NetworkPolicy-only (GAP-08)
- **Target:** Redis AUTH + NetworkPolicy (defense-in-depth)
- **Due:** 2026-Q2 (CA-005)
