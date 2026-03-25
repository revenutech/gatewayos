---
title: "Security Metrics Framework — API Gateway"
iso_ref: "ISO/IEC 27004:2016 Cl. 5-7, ISO/IEC 27001:2022 Cl. 9.1"
version: "1.0"
status: Active
last_review: 2026-03-25
next_review: 2026-06-25
owner: Security Architect
classification: Internal
---

# Security Metrics Framework — API Gateway

## 1. Metrics by Security Objective

### 1.1 Access Control Effectiveness (A.8.5, A.8.3, A.5.15)

| KPI | Formula | Target | Frequency | Source |
|-----|---------|--------|-----------|--------|
| JWT validation failure rate | 401 responses / total requests | < 1% | Real-time | Prometheus `krakend_router_response_size_count{status="401"}` |
| RBAC denial rate | 403 responses / total requests | < 0.5% | Real-time | Prometheus `{status="403"}` |
| Token revocation latency | Time from revoke action to all-instance enforcement | < 60s | Per event | Redis pub/sub timestamp delta |
| API key auth success rate | Successful API key auths / total API key attempts | > 99% | Hourly | `lua/api_key_auth.lua` metrics |
| Unauthorized access attempts | Count of 401+403 per tenant per hour | Alert > 50/min | Real-time | PrometheusRule `KrakenDAuthFailureSpike` |

### 1.2 Availability & Resilience (A.8.14, A.8.6, A.5.29)

| KPI | Formula | Target | Frequency | Source |
|-----|---------|--------|-----------|--------|
| Gateway uptime | 1 - (downtime / total time) | >= 99.9% | Monthly | Prometheus `up{job="krakend"}` |
| P95 response latency | histogram_quantile(0.95, ...) | < 100ms | Real-time | `krakend_router_response_time_seconds` |
| Circuit breaker open time | Total time CB is open per backend per week | < 5min/week | Weekly | `krakend_circuit_breaker_open` |
| Rate limit trigger rate | 429 responses / total | < 2% | Real-time | `{status="429"}` |
| Error rate (5xx) | 5xx / total | < 0.1% | Real-time | PrometheusRule `KrakenDHighErrorRate` |

### 1.3 Cryptographic Controls (A.8.24, A.5.14)

| KPI | Formula | Target | Frequency | Source |
|-----|---------|--------|-----------|--------|
| TLS compliance | Requests over TLS / total | 100% | Daily | Nginx Ingress metrics |
| mTLS coverage | Backends with mTLS / total backends | 100% | Weekly | Config audit |
| Certificate days to expiry | Cert expiry - now | > 30 days | Daily | cert-manager metrics |
| Cipher suite compliance | Requests with approved ciphers / total | 100% | Daily | Nginx logs |

### 1.4 Change & Configuration Management (A.8.32, A.8.9)

| KPI | Formula | Target | Frequency | Source |
|-----|---------|--------|-----------|--------|
| Config validation pass rate | CI pass / total CI runs | > 99% | Per commit | GitHub Actions |
| Config drift incidents | Unauthorized config changes detected | 0 | Daily | `config-audit/audit.sh` |
| Mean time to deploy | PR merge to production rollout | < 30min | Per deployment | CI/CD timestamps |
| Rollback count | Rollbacks / total deployments | < 5% | Monthly | Git history |

### 1.5 Incident Management (A.5.24-A.5.28)

| KPI | Formula | Target | Frequency | Source |
|-----|---------|--------|-----------|--------|
| Mean time to detect (MTTD) | Alert time - incident start | < 5min | Per incident | PagerDuty/Prometheus |
| Mean time to respond (MTTR) | Resolution time - detection time | < 1h (P1), < 4h (P2) | Per incident | Incident tracker |
| Security incidents per quarter | Count | Trending down | Quarterly | Incident register |
| False positive alert rate | False positives / total alerts | < 10% | Monthly | Alert triage records |

## 2. Measurement Procedures

### Collection
- **Prometheus:** Scrapes KrakenD `:8090` every 15s (ServiceMonitor)
- **OTel:** Exports traces every 10s to collector `:4317`
- **Lua scripts:** Business metrics to Redis, scraped by exporter
- **CI/CD:** GitHub Actions logs and artifact retention
- **CronJob:** Data retention metrics daily

### Reporting
- **Real-time:** Grafana dashboards (ops + security views)
- **Weekly:** Automated compliance summary (CI job)
- **Monthly:** SLA report to clients
- **Quarterly:** Management review input (ISO 27001 Cl. 9.3)

### Baselines
Established after 30 days of production data. Reviewed quarterly.

## 3. Management Review Input Template

See [Management Review Template](management-review-template.md) for the quarterly report structure.
