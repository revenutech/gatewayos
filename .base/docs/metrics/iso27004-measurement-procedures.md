---
title: "ISO 27004 Measurement Procedures — API Gateway"
iso_ref: "ISO/IEC 27004:2016 Cl. 5-9"
version: "1.0"
status: Active
last_review: 2026-03-25
owner: Security Architect
classification: Internal
---

# ISO 27004 — Measurement Procedures

> Each measurement follows ISO 27004 structure: Information Need → Attribute → Method → Function → Target → Evidence.

## 1. Access Control Effectiveness (A.8.5, A.8.3, A.5.15)

### M01 — JWT Validation Failure Rate

| Field | Value |
|-------|-------|
| **Information need** | Is authentication working correctly? Are there attacks or misconfigurations? |
| **Measured attribute** | Ratio of HTTP 401 responses to total requests |
| **Method** | Prometheus query: `sum(rate(krakend_router_response_size_count{status="401"}[5m])) / sum(rate(krakend_router_response_size_count[5m]))` |
| **Measurement function** | Ratio (percentage) |
| **Target** | < 1% under normal operation |
| **Baseline** | Established after 30 days of production data |
| **Collection frequency** | Continuous (15s scrape interval) |
| **Reporting frequency** | Real-time (dashboard), weekly (summary), quarterly (management review) |
| **Owner** | DevSecOps Lead |
| **Indicator** | Spike above 5% → access control anomaly alert; spike above 10% → potential attack |
| **Decision criteria** | Sustained > 5% for 10min → investigate; > 10% → invoke IRP |
| **Evidence location** | Prometheus TSDB, Grafana dashboard |

### M02 — Authorization Denial Rate

| Field | Value |
|-------|-------|
| **Information need** | Are RBAC rules correctly configured? Are users attempting unauthorized access? |
| **Measured attribute** | HTTP 403 responses per tenant per hour |
| **Method** | `sum by (tenant_id) (increase(krakend_router_response_size_count{status="403"}[1h]))` |
| **Target** | < 0.5% of total, no sustained spikes |
| **Decision criteria** | Single tenant > 50/hr → possible misconfiguration or attack |

### M03 — Token Revocation Coverage

| Field | Value |
|-------|-------|
| **Information need** | Are revoked tokens being blocked across all instances? |
| **Measured attribute** | Count of revoked tokens/users/tenants in Redis |
| **Method** | `redis-cli SCARD revoked_tokens`, `redis-cli SCARD revoked_users`, `redis-cli SCARD revoked_tenants` |
| **Collection frequency** | Daily (CronJob reports) |
| **Target** | All revocations propagated, 0 revoked tokens passing validation |

## 2. Availability & Resilience (A.8.14, A.8.6, A.5.29)

### M04 — Gateway Uptime

| Field | Value |
|-------|-------|
| **Information need** | Is the SLA being met? |
| **Measured attribute** | Proportion of time gateway responds to health checks |
| **Method** | `avg_over_time(up{job="krakend"}[30d])` |
| **Target** | >= 99.9% (42min/month max downtime) |
| **Reporting** | Monthly SLA report to clients |
| **Decision criteria** | < 99.9% monthly → corrective action required |

### M05 — P95 Response Latency

| Field | Value |
|-------|-------|
| **Information need** | Is gateway overhead acceptable? Are backends degrading? |
| **Measured attribute** | 95th percentile response time |
| **Method** | `histogram_quantile(0.95, sum(rate(krakend_router_response_time_seconds_bucket[5m])) by (le))` |
| **Target** | < 100ms (gateway-only overhead) |
| **Decision criteria** | > 1s sustained → `KrakenDHighLatency` alert |

### M06 — Circuit Breaker Open Duration

| Field | Value |
|-------|-------|
| **Information need** | How often are backends degraded? What's the impact on availability? |
| **Measured attribute** | Total minutes per week CB is open, per backend |
| **Method** | `sum by (name) (krakend_circuit_breaker_open) * 15 / 60` (15s scrape → minutes) |
| **Target** | < 5 minutes/week per backend |
| **Decision criteria** | > 5min/week → investigate backend health, review CB thresholds |

### M07 — Error Rate (5xx)

| Field | Value |
|-------|-------|
| **Information need** | Is the gateway producing server errors? |
| **Measured attribute** | Ratio of 5xx responses to total |
| **Method** | `sum(rate(krakend_router_response_size_count{status=~"5.."}[5m])) / sum(rate(krakend_router_response_size_count[5m]))` |
| **Target** | < 0.1% |
| **Decision criteria** | > 5% for 5min → `KrakenDHighErrorRate` critical alert → IRP P2 |

## 3. Cryptographic Controls (A.8.24, A.5.14)

### M08 — TLS Compliance Rate

| Field | Value |
|-------|-------|
| **Information need** | Is all traffic encrypted? Any TLS downgrade attempts? |
| **Measured attribute** | Requests over TLS vs total |
| **Method** | Nginx Ingress metrics: `nginx_ingress_controller_requests{scheme="https"}` vs total |
| **Target** | 100% |
| **Decision criteria** | Any HTTP (non-TLS) traffic → configuration error |

### M09 — Certificate Time to Expiry

| Field | Value |
|-------|-------|
| **Information need** | Will certificates expire before renewal? |
| **Measured attribute** | Days until mTLS client cert expires |
| **Method** | `(certmanager_certificate_expiration_timestamp_seconds - time()) / 86400` |
| **Target** | > 30 days at all times |
| **Decision criteria** | < 30 days → warning; < 7 days → critical |

### M10 — mTLS Backend Coverage

| Field | Value |
|-------|-------|
| **Information need** | Are all backends protected with mTLS? |
| **Measured attribute** | Backends with mTLS configured / total backends |
| **Method** | Config audit: count backends in `mtls_backend.tmpl` vs `service_routes.json` |
| **Collection frequency** | Per CI run |
| **Target** | 100% of production backends |

## 4. Configuration Management (A.8.9, A.8.32)

### M11 — Config Validation Pass Rate

| Field | Value |
|-------|-------|
| **Information need** | Are configuration changes being validated before deployment? |
| **Measured attribute** | CI validation pass / total CI runs |
| **Method** | GitHub Actions API: `gh api repos/.../actions/runs --jq '.workflow_runs[] | select(.name=="CI — Gateway") | .conclusion'` |
| **Target** | > 99% |
| **Decision criteria** | < 95% → review change process quality |

### M12 — Configuration Drift Detection

| Field | Value |
|-------|-------|
| **Information need** | Are environments consistent? Any unauthorized changes? |
| **Measured attribute** | Config audit failures (env drift, missing annotations) |
| **Method** | `tools/config-audit/audit.sh --strict` exit code |
| **Collection frequency** | Per CI run + daily scheduled |
| **Target** | 0 drift incidents |

### M13 — Mean Time to Deploy

| Field | Value |
|-------|-------|
| **Information need** | How quickly can security patches be deployed? |
| **Measured attribute** | Time from PR merge to production rollout |
| **Method** | CI workflow timestamps: merge event → deployment completion |
| **Target** | < 30 minutes for standard, < 15 minutes for emergency |

## 5. Incident Management (A.5.24-A.5.28)

### M14 — Mean Time to Detect (MTTD)

| Field | Value |
|-------|-------|
| **Information need** | How quickly are security events detected? |
| **Measured attribute** | Time between incident start and first alert |
| **Method** | Prometheus alert timestamp - first anomalous data point |
| **Target** | < 5 minutes for P1/P2 |
| **Decision criteria** | > 15min → review alerting thresholds |

### M15 — Mean Time to Respond (MTTR)

| Field | Value |
|-------|-------|
| **Information need** | How quickly are incidents resolved? |
| **Measured attribute** | Time from detection to resolution |
| **Method** | Incident tracker timestamps |
| **Target** | < 1h (P1), < 4h (P2), < 24h (P3) |
| **Reporting** | Per incident, aggregated quarterly |

### M16 — Security Incidents Count

| Field | Value |
|-------|-------|
| **Information need** | Is the security posture improving over time? |
| **Measured attribute** | Number of security incidents per quarter by severity |
| **Method** | Incident register count |
| **Target** | Trending downward quarter-over-quarter |

### M17 — False Positive Alert Rate

| Field | Value |
|-------|-------|
| **Information need** | Are alerts actionable or causing alert fatigue? |
| **Measured attribute** | Alerts dismissed as false positive / total alerts |
| **Method** | Alert triage records |
| **Target** | < 10% |
| **Decision criteria** | > 20% → tune alerting thresholds |

## 6. Compliance (A.5.36)

### M18 — ISMS Document Currency

| Field | Value |
|-------|-------|
| **Information need** | Are ISMS documents up to date? |
| **Measured attribute** | Documents past review date / total documents |
| **Method** | Parse `next_review` frontmatter across `.base/docs/` |
| **Target** | 0 overdue documents |
| **Collection frequency** | Monthly |

### M19 — Corrective Action Closure Rate

| Field | Value |
|-------|-------|
| **Information need** | Are nonconformities being addressed? |
| **Measured attribute** | Closed CAs / total CAs |
| **Method** | Count from `operations/corrective-actions.md` |
| **Target** | > 90% within due date |

### M20 — Compliance CI Pass Rate

| Field | Value |
|-------|-------|
| **Information need** | Is the gateway maintaining compliance through automation? |
| **Measured attribute** | ISO compliance workflow pass rate |
| **Method** | GitHub Actions: compliance.yml pass/fail |
| **Target** | 100% on main branch |

---

## Measurement Program Schedule

| Frequency | Measurements | Output |
|-----------|-------------|--------|
| **Continuous** (15s) | M01, M02, M04, M05, M06, M07, M08 | Real-time dashboard |
| **Daily** | M03, M09, M12 | Automated report (CronJob + CI) |
| **Per-commit** | M11, M13, M20 | CI pipeline results |
| **Weekly** | M01-M12 aggregated | Weekly security summary |
| **Monthly** | M04 (SLA), M17, M18 | SLA report, document review |
| **Quarterly** | M14-M19 aggregated | Management review input |
| **Per-incident** | M14, M15 | Incident report |

## Baselines and Trending

- **Baseline period:** First 30 days of production
- **Trending:** Quarter-over-quarter comparison in management review
- **Threshold adjustment:** Based on baseline + operational experience
- **Escalation:** Measurements consistently outside target → corrective action

---

> **Cross-references:** [Metrics Framework](security-metrics-framework.md) | [Management Review Template](management-review-template.md) | [PrometheusRules](../../k8s/manifests/prometheusrule-compliance.yaml)
