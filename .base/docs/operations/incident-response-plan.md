---
title: "Incident Response Plan — API Gateway"
iso_ref: "ISO 27001:2022 A.5.24-5.28, Cl. 8.1"
version: "1.0"
status: Active
owner: DevSecOps Lead
classification: Confidential
---

# Incident Response Plan — API Gateway

## 1. Severity Classification

| Level | Name | Criteria | Response Time | Escalation |
|:-----:|------|----------|:------------:|------------|
| P1 | Critical | Full gateway outage, data breach, all tenants affected | < 15min | ISMS Owner + Management |
| P2 | High | Partial outage, single backend cascade, auth bypass suspected | < 30min | Security Architect |
| P3 | Medium | Elevated error rates, CB open > 5min, rate limit anomaly | < 2h | DevSecOps Lead |
| P4 | Low | Non-impacting alert, config drift detected, single false positive | < 24h | On-call engineer |

## 2. Detection (A.5.25)

| Source | Alert | Severity Trigger |
|--------|-------|-----------------|
| Prometheus | `KrakenDHighErrorRate` > 5% | P2 |
| Prometheus | `KrakenDCircuitBreakerOpen` | P3 |
| Prometheus | `KrakenDAuthFailureSpike` > 50/s | P2 |
| Prometheus | `KrakenDReducedRedundancy` < 2 pods | P1 |
| Prometheus | `KrakenDCertExpiringIn7Days` | P2 |
| CI | Config validation failure | P4 |
| CI | Compliance audit failure | P3 |
| Manual | Security event report | P2-P4 (triage) |

## 3. Response Procedures (A.5.26)

### 3.1 Containment

| Scenario | Immediate Action | Command/Runbook |
|----------|-----------------|-----------------|
| Suspected token theft | Revoke token via Redis | `redis-cli SADD revoked_tokens "<jti>"` |
| Tenant compromise | Revoke all tenant tokens | `redis-cli SADD revoked_tenants "<tenant_id>"` |
| Backend cascade | Verify CB is open (automatic) | Check Prometheus `krakend_circuit_breaker_open` |
| DDoS detected | Enable strict IP allowlist | Uncomment `whitelist-source-range` in ingress |
| Config tampering | Rollback to last known good | `git revert <commit>` + CI redeploy |
| Cert compromise | Rotate certificates immediately | `kubectl delete secret krakend-mtls-client-cert` (cert-manager reissues) |

### 3.2 Eradication
1. Identify root cause via OTel traces + access logs
2. Apply fix (config change, policy update, image update)
3. Validate fix in staging before production
4. Deploy via normal CI/CD pipeline

### 3.3 Recovery
1. Verify all backends healthy (`/v1/dashboard/health`)
2. Confirm metrics return to baseline
3. Clear circuit breakers if needed
4. Remove containment measures (IP restrictions, tenant revocations)
5. Monitor for recurrence (24h watch period)

## 4. Evidence Collection (A.5.28)
- Export audit evidence logs: `kubectl logs -l app.kubernetes.io/name=krakend --since=24h | grep audit_evidence`
- Export Prometheus metrics: snapshot affected time range
- Export OTel traces: filter by correlation_id
- Preserve Git state: tag commit at time of incident

## 5. Post-Incident (A.5.27)
1. **Post-mortem:** Within 5 business days of P1/P2
2. **Root cause analysis:** 5-Whys methodology
3. **Corrective actions:** Logged in `corrective-actions.md`
4. **Lessons learned:** Update threat model, risk register
5. **BACEN notification:** Within 24h if regulatory impact (Res. 4.893)
