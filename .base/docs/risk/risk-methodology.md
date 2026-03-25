---
title: "Risk Assessment Methodology — API Gateway"
iso_ref: "ISO/IEC 27005:2022 Cl. 7-8, ISO/IEC 27001:2022 Cl. 6.1.2"
version: "1.0"
status: Approved
last_review: 2026-03-25
next_review: 2026-09-25
owner: Security Architect
classification: Internal
---

# Risk Assessment Methodology — API Gateway

## 1. Purpose

Defines the systematic process for identifying, analyzing, and evaluating information security risks to the API Gateway, in accordance with ISO/IEC 27005:2022 and ISO 27001:2022 Cl. 6.1.2.

## 2. Scope

Covers all assets, threats, and vulnerabilities within the Gateway ISMS scope as defined in `isms/scope-statement.md`.

## 3. Risk Criteria

### 3.1 Likelihood Scale

| Level | Score | Definition | Frequency |
|-------|-------|-----------|-----------|
| Rare | 1 | Highly unlikely to occur | < 1x per 5 years |
| Unlikely | 2 | Could occur but not expected | 1x per 1-5 years |
| Possible | 3 | Might occur at some time | 1x per year |
| Likely | 4 | Will probably occur | 1x per quarter |
| Almost Certain | 5 | Expected to occur frequently | 1x per month or more |

### 3.2 Impact Scale

| Level | Score | Confidentiality | Integrity | Availability | Financial | Regulatory |
|-------|-------|----------------|-----------|--------------|-----------|------------|
| Negligible | 1 | No data exposed | No data corruption | < 5min downtime | < R$1k | No regulatory impact |
| Minor | 2 | Internal data exposed | Minor data errors, recoverable | 5-30min downtime | R$1k-10k | Warning from regulator |
| Moderate | 3 | Limited PII exposed | Significant errors, partial recovery | 30min-4h downtime | R$10k-100k | Formal inquiry |
| Major | 4 | Bulk PII/financial data exposed | Critical data corruption | 4h-24h downtime | R$100k-1M | Fine, remediation order |
| Catastrophic | 5 | Full system compromise, all data | Irrecoverable data loss | > 24h downtime | > R$1M | License revocation, criminal |

### 3.3 Risk Matrix (5x5)

```
Impact →        1-Neg    2-Min    3-Mod    4-Maj    5-Cat
Likelihood ↓  ┌────────┬────────┬────────┬────────┬────────┐
5-Almost Cert  │   5    │  10    │  15    │  20    │  25    │
4-Likely       │   4    │   8    │  12    │  16    │  20    │
3-Possible     │   3    │   6    │   9    │  12    │  15    │
2-Unlikely     │   2    │   4    │   6    │   8    │  10    │
1-Rare         │   1    │   2    │   3    │   4    │   5    │
               └────────┴────────┴────────┴────────┴────────┘
```

### 3.4 Risk Levels

| Risk Score | Level | Color | Required Action |
|------------|-------|-------|-----------------|
| 1-4 | Low | Green | Accept or monitor; review annually |
| 5-9 | Medium | Yellow | Treatment plan within 90 days; review quarterly |
| 10-14 | High | Orange | Treatment plan within 30 days; review monthly |
| 15-25 | Critical | Red | Immediate treatment; escalate to ISMS Owner; review weekly |

### 3.5 Risk Appetite

| Risk Category | Appetite | Rationale |
|---------------|----------|-----------|
| Confidentiality (data breach) | Very Low | Fintech regulatory obligations (BACEN, LGPD) |
| Integrity (data corruption) | Very Low | Financial transaction accuracy is critical |
| Availability (service outage) | Low | 99.9% SLA commitment to clients |
| Compliance (regulatory) | Zero | No tolerance for regulatory violations |
| Reputation | Low | Client trust is fundamental |

## 4. Risk Assessment Process

### 4.1 Risk Identification (ISO 27005 Cl. 8.2)

**Methods:**
1. **Threat modeling** — STRIDE analysis per component (see `risk/threat-model.md`)
2. **Vulnerability assessment** — CI/CD scanning (Trivy, govulncheck, Semgrep)
3. **Incident history** — Lessons from past incidents
4. **Control gap analysis** — Controls matrix vs. SoA
5. **External intelligence** — CVE databases, BACEN advisories, CERT.br

**Asset categories:**
- Configuration assets (KrakenD templates, K8s manifests)
- Cryptographic assets (TLS certs, mTLS certs, JWKS keys)
- Runtime data (JWT tokens, API keys, rate limit counters)
- Audit data (access logs, metrics, traces)
- Infrastructure (K8s pods, network, storage)

### 4.2 Risk Analysis (ISO 27005 Cl. 8.3)

For each identified risk:
1. Determine threat source and threat event
2. Identify exploitable vulnerabilities
3. Assess existing controls (effectiveness rating: None/Partial/Full)
4. Determine likelihood (1-5) considering existing controls
5. Determine impact (1-5) across CIA + financial + regulatory
6. Calculate risk score = Likelihood x max(Impact across categories)

### 4.3 Risk Evaluation (ISO 27005 Cl. 8.4)

- Compare risk score against risk levels (§3.4)
- Compare against risk appetite (§3.5)
- Prioritize risks for treatment
- Document in risk register

### 4.4 Risk Treatment (ISO 27005 Cl. 10)

| Option | When | Example |
|--------|------|---------|
| **Mitigate** | Risk above appetite, controls available | Add rate limiting, enable mTLS |
| **Accept** | Risk within appetite, cost of control > benefit | Low-severity false positives in bloom filter |
| **Transfer** | Risk can be shared with third party | Cyber insurance, cloud provider SLA |
| **Avoid** | Risk source can be eliminated | Disable unused endpoint, remove feature |

### 4.5 Risk Monitoring

- **Continuous:** Prometheus alerts for control failures
- **Weekly:** Critical risk status review
- **Monthly:** High risk status review
- **Quarterly:** Full risk register review + management review input
- **Trigger-based:** After incidents, architecture changes, regulatory updates

## 5. Document Control

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | 2026-03-25 | Security Architect | Initial methodology |
