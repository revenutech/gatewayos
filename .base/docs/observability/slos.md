# SLOs & SLIs

Service Level Objectives derived from alert thresholds.

## SLO Definitions

### Availability

| SLI | Target | Measurement | Alert |
|-----|--------|-------------|-------|
| Success rate (non-5xx) | 99% | `1 - (5xx / total)` over 1h | KrakenDTenantErrorBudgetBurn |
| Gateway uptime | 99.9% | Pod availability ≥ 2 replicas | KrakenDReducedRedundancy |

**Error budget:** 1% per tenant per hour. If exceeded for 10 minutes, warning alert fires.

### Latency

| SLI | Target | Measurement | Alert |
|-----|--------|-------------|-------|
| p95 response time | < 1s | `histogram_quantile(0.95, ...)` | KrakenDHighLatency |

### Revenue Continuity

| SLI | Target | Measurement | Alert |
|-----|--------|-------------|-------|
| Revenue event rate | > 0 events/30m | Successful postings + settlements + pix | KrakenDNoRevenueEvents |

### Capacity

| SLI | Target | Measurement | Alert |
|-----|--------|-------------|-------|
| HPA headroom | < max replicas | Current vs max replicas | KrakenDCapacityAtMaximum |

### Security

| SLI | Target | Measurement | Alert |
|-----|--------|-------------|-------|
| Auth failure rate | < 5% | `(401+403) / total` | KrakenDAccessControlAnomaly |
| Auth failure volume | < 50/s | `rate(401+403)` | KrakenDAuthFailureSpike |
| mTLS cert validity | > 30 days | Certificate expiry timestamp | KrakenDCertExpiringIn30Days |

## Error Budget Tracking

Per-tenant error budget over 1 hour:

```
Budget = 1% of total requests
Consumed = 5xx requests / total requests
Remaining = Budget - Consumed
```

When remaining budget reaches 0, the `KrakenDTenantErrorBudgetBurn` alert fires.

## SLO Dashboard Queries

### Availability (30d rolling)

```promql
1 - (
  sum(increase(krakend_router_response_size_count{status=~"5.."}[30d]))
  / sum(increase(krakend_router_response_size_count[30d]))
)
```

### Latency p95 (5m rolling)

```promql
histogram_quantile(0.95,
  sum(rate(krakend_router_response_time_seconds_bucket[5m])) by (le)
)
```
