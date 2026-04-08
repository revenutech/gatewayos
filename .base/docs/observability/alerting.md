# Alerting

14 PrometheusRule alerts across 3 groups.

## Operational Alerts (krakend.rules)

| Alert | Condition | Duration | Severity | Response |
|-------|-----------|----------|----------|----------|
| KrakenDHighErrorRate | >5% 5xx responses | 5m | critical | Check backend health, review logs, escalate if persistent |
| KrakenDCircuitBreakerOpen | Any CB open | 1m | warning | Identify failing backend, check its health/logs |
| KrakenDHighLatency | p95 > 1s | 5m | warning | Check backend latency, review HPA scaling, DB performance |
| KrakenDRateLimitSpike | >100/s 429 responses | 2m | info | Review tenant traffic patterns, consider limit increase |

## Business Alerts (krakend.business.rules)

| Alert | Condition | Duration | Severity | Response |
|-------|-----------|----------|----------|----------|
| KrakenDTenantErrorBudgetBurn | >1% 5xx per tenant over 1h | 10m | warning | Investigate tenant-specific issues, check backend logs |
| KrakenDNoRevenueEvents | 0 postings/settlements/pix (200) for 30m | 30m | warning | Verify business operations, check backend availability |
| KrakenDAuthFailureSpike | >50/s 401/403 | 5m | warning | Possible credential stuffing or misconfiguration |
| KrakenDTierRateLimitExhaustion | >10/s 429 per tier | 5m | info | Tier upgrade candidate, review tier limits |

## Compliance Alerts (krakend.compliance.rules)

| Alert | Condition | Duration | Severity | ISO Control | Response |
|-------|-----------|----------|----------|-------------|----------|
| KrakenDCertExpiringIn30Days | mTLS cert < 30 days | 1h | warning | A.8.24 | Check cert-manager health |
| KrakenDCertExpiringIn7Days | mTLS cert < 7 days | 10m | critical | A.8.24 | Manual cert renewal if auto-renewal failed |
| KrakenDConfigValidationFailure | CI failure | 0m | warning | A.8.9 | Review failed CI run, fix config |
| KrakenDAccessControlAnomaly | >5% auth failures for 10m | 10m | warning | A.5.15 | Investigate auth issues, possible attack |
| KrakenDCapacityAtMaximum | HPA at max replicas | 15m | warning | A.8.6 | Increase HPA max, review resource usage |
| KrakenDReducedRedundancy | <2 replicas available | 5m | critical | A.8.14 | Check pod health, node availability |

## Alert Routing

Alerts are labeled with:
- `service: krakend` — identifies the gateway
- `severity: critical|warning|info` — for routing to appropriate channels
- `category: business|security|compliance` — for team routing
- `iso_control: A.x.xx` — for compliance tracking
