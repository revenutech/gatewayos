# Performance Tuning

## Global Settings

| Setting | Value | Source |
|---------|-------|--------|
| Request timeout | 3000ms | krakend.tmpl |
| Cache TTL | 300s | krakend.tmpl |
| Dashboard timeout | 5000ms | dashboard_v1.json |
| Dashboard health timeout | 3000ms | dashboard_v1.json |

## Resource Allocation

### KrakenD Container

| Setting | Dev | Production |
|---------|-----|------------|
| CPU request | 250m | 500m |
| CPU limit | 1000m | 2000m |
| Memory request | 128Mi | 256Mi |
| Memory limit | 512Mi | 1Gi |

### Envoy Sidecar

| Setting | Value |
|---------|-------|
| CPU request | 50m |
| CPU limit | 200m |
| Memory request | 64Mi |
| Memory limit | 128Mi |

## Horizontal Pod Autoscaler

| Setting | Value |
|---------|-------|
| Min replicas | 2 |
| Max replicas | 8 |
| CPU target | 60% utilization |
| Memory target | 75% utilization |
| Scale up | Instant — 100%/15s or +4 pods/15s (max policy) |
| Scale down | Conservative — 10%/60s, 300s stabilization window |

The aggressive scale-up and conservative scale-down policy ensures the gateway responds quickly to traffic spikes but doesn't flap under variable load.

## Circuit Breaker Tuning

Per-backend sensitivity is tuned based on service criticality:

| Sensitivity | Backends | Config | Use Case |
|------------|----------|--------|----------|
| Very strict | Identos | 2 errors/30s/5s | Auth must fail fast |
| Strict | Paymentos | 3 errors/60s/15s | Payments are critical |
| Standard | LedgerOS, OnboardOS, AccountOS | 5 errors/60s/10s | General services |
| Lenient | AtmOS | 10 errors/120s/30s | Hardware-dependent, intermittent |

## Rate Limiting

| Strategy | Latency | Accuracy | Use Case |
|----------|---------|----------|----------|
| Native KrakenD | ~0ms | Per-instance | Default for most endpoints |
| Redis distributed | ~1ms | Cross-instance | High-accuracy global limits |
| Tiered | ~1ms | Cross-instance | Subscription-based differentiation |

## Caching

### HTTP Cache

Dashboard ledger backend uses `qos/http-cache` with `shared: true` for response caching at the gateway level.

### Redis Response Cache

`response_cache.lua` provides Redis-backed caching with configurable TTL (default 60s).

## Bloom Filter Memory

Token revocation Bloom filter:
- **Capacity:** 10M tokens
- **FPR:** 0.00001%
- **Memory:** ~10MB per instance
- **TTL:** 3600s per token entry

## Concurrent Backend Calls

Dashboard overview uses `concurrent_calls: 4` to query all backends in parallel, reducing overall latency to the slowest backend response time rather than the sum.
