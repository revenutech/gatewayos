---
title: "ISMS Manual — Revenu Platform API Gateway"
iso_ref: ISO/IEC 27001:2022 Clause 4.4, ISO/IEC 27003:2017
version: "1.0"
status: Approved
last_review: 2026-03-25
next_review: 2026-09-25
owner: ISMS Owner
classification: Internal
---

# ISMS Manual — API Gateway

## 1. Introduction

This manual describes the Information Security Management System (ISMS) for the Revenu Platform API Gateway. It serves as the central reference document, linking all ISMS processes, policies, and documentation in accordance with ISO/IEC 27001:2022 and ISO/IEC 27003:2017 implementation guidance.

## 2. ISMS Overview

### 2.1 PDCA Cycle

The ISMS follows the Plan-Do-Check-Act cycle as required by ISO 27001:

```
┌─────────────────────────────────────────────────────────────┐
│                        PLAN (Cl. 4-7)                       │
│  Context analysis → Risk assessment → Controls selection    │
│  Policies → Objectives → Resource planning                  │
├─────────────────────────────────────────────────────────────┤
│                        DO (Cl. 8)                           │
│  Implement controls → Operate gateway → Execute procedures  │
│  Incident response → Change management → Training           │
├─────────────────────────────────────────────────────────────┤
│                        CHECK (Cl. 9)                        │
│  Metrics collection → Internal audit → Management review    │
│  Compliance validation → Performance evaluation             │
├─────────────────────────────────────────────────────────────┤
│                        ACT (Cl. 10)                         │
│  Corrective actions → Continual improvement → Lessons       │
│  Policy updates → Risk re-assessment → Control tuning       │
└─────────────────────────────────────────────────────────────┘
```

### 2.2 ISMS Process Interactions

```
Interested Parties ──→ Requirements ──→ ISMS Scope (Cl. 4.3)
                                            │
                                            ▼
                                    Risk Assessment (Cl. 6.1.2)
                                            │
                                            ▼
                                    Risk Treatment (Cl. 6.1.3)
                                            │
                                            ▼
                                    Statement of Applicability
                                            │
                              ┌─────────────┼─────────────┐
                              ▼             ▼             ▼
                         Technical     Process        Documentation
                         Controls      Controls       Controls
                              │             │             │
                              ▼             ▼             ▼
                         Monitoring    Auditing       Reviewing
                              │             │             │
                              └─────────────┼─────────────┘
                                            ▼
                                    Continual Improvement
                                            │
                                            ▼
                              Managed Information Security ──→ Interested Parties
```

## 3. Document Map

### 3.1 Mandatory Documents (ISO 27001)

| ISO Ref | Document | Location | Status |
|---------|----------|----------|--------|
| Cl. 4.3 | ISMS Scope | `isms/scope-statement.md` | Active |
| Cl. 5.2 | Information Security Policy | `isms/information-security-policy.md` | Active |
| Cl. 5.3 | Roles & Responsibilities | `isms/roles-responsibilities.md` | Active |
| Cl. 4.2 | Interested Parties | `isms/interested-parties.md` | Active |
| Cl. 6.1.2 | Risk Assessment Methodology | `risk/risk-methodology.md` | Pending |
| Cl. 6.1.2 | Risk Register | `risk/risk-register.md` | Pending |
| Cl. 6.1.3 | Risk Treatment Plan | `risk/risk-treatment-plan.md` | Pending |
| Cl. 6.1.3d | Statement of Applicability | `risk/statement-of-applicability.md` | Pending |
| Cl. 6.2 | Security Objectives | `isms/information-security-policy.md` §3 | Active |
| Cl. 7.2 | Competence Evidence | HR records (external) | N/A |
| Cl. 8.1 | Operational Procedures | `operations/runbooks/` | Pending |
| Cl. 9.1 | Monitoring Results | `metrics/security-metrics-framework.md` | Pending |
| Cl. 9.2 | Internal Audit Results | `operations/internal-audit-procedure.md` | Pending |
| Cl. 9.3 | Management Review Results | `metrics/management-review-template.md` | Pending |
| Cl. 10.1 | Nonconformities & Corrective Actions | `operations/corrective-actions.md` | Pending |

### 3.2 Technical Evidence (Compliance-as-Code)

| Control Area | Evidence | Location |
|-------------|----------|----------|
| Authentication (A.8.5) | JWT validator config, API key auth | `krakend/partials/jwt_validator.tmpl`, `lua/api_key_auth.lua` |
| Access Control (A.8.3) | RBAC per endpoint, CEL policies | `krakend/endpoints/*.json`, `security/policies.json` |
| Cryptography (A.8.24) | TLS/mTLS config, cipher suites | `krakend/partials/mtls_backend.tmpl`, `k8s/manifests/mtls-certificates.yaml` |
| Network Security (A.8.20) | Network policies, ingress rules | `k8s/policies/*.yaml`, `k8s/manifests/ingress.yaml` |
| Logging (A.8.15) | Access logs, audit trail | `krakend/partials/lua/access_log.lua`, `lua/audit_evidence.lua` |
| Monitoring (A.8.16) | Prometheus, OTel, alerts | `krakend/partials/telemetry.tmpl`, `k8s/manifests/prometheusrule.yaml` |
| Capacity (A.8.6) | Rate limiting, HPA, PDB | `krakend/partials/rate_limiter*.tmpl`, `k8s/manifests/hpa.yaml` |
| Redundancy (A.8.14) | Multi-replica, anti-affinity | `k8s/manifests/deployment.yaml`, `k8s/manifests/pdb.yaml` |
| Env Separation (A.8.31) | Per-env settings | `krakend/settings/{dev,staging,prod}.json` |
| Change Management (A.8.32) | CI pipeline, PR reviews | `.github/workflows/ci.yml`, CODEOWNERS |

### 3.3 Supporting Documentation

| Document | Purpose | Location |
|----------|---------|----------|
| Threat Model (STRIDE) | Risk identification | `risk/threat-model.md` |
| Controls Matrix | 93-control mapping | `compliance/controls-matrix.md` |
| Incident Response Plan | Security incident handling | `operations/incident-response-plan.md` |
| Business Continuity Plan | Disaster recovery | `operations/business-continuity-plan.md` |
| Change Management | Change control process | `operations/change-management.md` |
| Runbooks | Operational procedures | `operations/runbooks/` |

## 4. ISMS Processes

### 4.1 Risk Management Process (ISO 27005)

1. **Context Establishment** → Scope + interested parties (Cl. 4.1-4.3)
2. **Risk Identification** → Threat model + asset inventory
3. **Risk Analysis** → Likelihood x Impact matrix (5x5)
4. **Risk Evaluation** → Compare against risk appetite
5. **Risk Treatment** → Select controls from Annex A (SoA)
6. **Risk Monitoring** → Continuous metrics + periodic review

### 4.2 Performance Evaluation (ISO 27004)

1. **Define metrics** → KPIs per security objective
2. **Collect data** → Prometheus, OTel, audit logs
3. **Analyze** → Dashboards, trend analysis
4. **Report** → Management review (quarterly)
5. **Improve** → Adjust controls, update policies

### 4.3 Internal Audit (Cl. 9.2)

- **Frequency:** Annual (minimum), triggered by significant changes
- **Scope:** All ISMS processes and controls
- **Method:** Checklist-based review against controls matrix
- **Output:** Audit report with findings, nonconformities, recommendations
- **Follow-up:** Corrective actions tracked to closure

### 4.4 Management Review (Cl. 9.3)

**Inputs:**
- Status of actions from previous reviews
- Changes in external/internal issues
- Information security performance (metrics)
- Audit results
- Risk assessment updates
- Opportunities for improvement

**Outputs:**
- Decisions on improvement opportunities
- Changes to ISMS (scope, policies, objectives)
- Resource allocation decisions

**Frequency:** Quarterly (minimum)

### 4.5 Continual Improvement (Cl. 10)

- Corrective actions for nonconformities
- Lessons learned from incidents
- Metrics trend analysis driving control adjustments
- Technology updates (KrakenD upgrades, new security features)
- Regulatory changes (BACEN, LGPD updates)

## 5. Integration with LedgerOS ISMS

This Gateway ISMS operates as a **sub-ISMS** within the broader Revenu Platform ISMS:

| Aspect | Gateway ISMS | Platform ISMS (LedgerOS) |
|--------|-------------|-------------------------|
| Scope | API Gateway components | All platform components |
| Policies | B1-GW (derived from B1) | B1-B7 policy series |
| Risk register | Gateway-specific risks | Platform-wide risk register |
| Controls | Gateway-applicable subset | Full 93-control matrix |
| Metrics | Gateway KPIs | Platform-wide metrics |
| Audit | Gateway controls | Full ISMS audit |

**Reference:** LedgerOS ISMS → `ledgeros/.base/plans/08-security/iso27000-security-framework.md`

## 6. Document Control

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | 2026-03-25 | ISMS Owner | Initial ISMS Manual |

---

> **Navigation:**
> - [Scope Statement](scope-statement.md) | [Security Policy](information-security-policy.md) | [Roles](roles-responsibilities.md) | [Interested Parties](interested-parties.md)
> - [Risk Methodology](../risk/risk-methodology.md) | [Risk Register](../risk/risk-register.md) | [SoA](../risk/statement-of-applicability.md)
> - [Controls Matrix](../compliance/controls-matrix.md)
> - [Metrics Framework](../metrics/security-metrics-framework.md)
> - [IRP](../operations/incident-response-plan.md) | [BCP](../operations/business-continuity-plan.md) | [Runbooks](../operations/runbooks/)
