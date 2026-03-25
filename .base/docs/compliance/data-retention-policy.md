---
title: "Data Retention Policy — API Gateway"
iso_ref: "ISO 27001:2022 A.8.10 (Information deletion), A.5.33 (Protection of records)"
version: "1.0"
status: Active
last_review: 2026-03-25
owner: Compliance Officer
classification: Internal
---

# Data Retention Policy — API Gateway

## 1. Retention Schedule

| Data Category | Storage | Retention | Deletion Method | ISO Control |
|---------------|---------|-----------|-----------------|-------------|
| Rate limit counters | Redis | 2 minutes (window) + 2min buffer | TTL auto-expire | A.8.10 |
| Tiered rate limit counters | Redis | 2 minutes + 2min buffer | TTL auto-expire | A.8.10 |
| Response cache | Redis | 60s default (configurable per endpoint) | TTL auto-expire | A.8.10 |
| Business metrics counters | Redis | 1 hour rolling window | TTL auto-expire | A.8.10 |
| Cumulative revenue metrics | Redis | Indefinite (total counters) | Manual review quarterly | A.5.33 |
| Circuit breaker state | Redis | 2x recovery_time | TTL auto-expire | A.8.10 |
| Revoked tokens SET | Redis | Token TTL (1 hour) | TTL on individual entries | A.8.10 |
| Revoked users SET | Redis | Until manually removed | Manual removal via admin | A.5.33 |
| Access logs (stdout) | K8s log collector | 90 days | Log rotation policy | A.8.15 |
| Audit evidence logs | K8s log collector | 1 year (regulatory) | Log rotation policy | A.5.28 |
| Prometheus metrics | Prometheus TSDB | 15 days | TSDB retention config | A.8.16 |
| OTel traces | OTel Collector → backend | 30 days | Backend retention policy | A.8.15 |
| Git history | GitHub | Indefinite | Not deleted (audit trail) | A.5.33 |

## 2. Enforcement

- **Automated:** Redis TTL on all ephemeral data, CronJob daily cleanup
- **Manual:** Quarterly review of cumulative counters and revocation lists
- **Monitoring:** CronJob logs retention metrics, alert on orphan keys (no TTL)

## 3. LGPD Compliance

The API Gateway does **not store PII**. All personal data is in transit only:
- JWT tokens contain `sub` (user ID) — passed through, not stored
- `tenant_id` — business identifier, not PII
- Access logs contain user IDs — subject to 90-day retention
- No credit card, CPF, or other sensitive data stored

For LGPD data subject requests (access, deletion, portability), contact the backend service that owns the data (LedgerOS, Identos).
