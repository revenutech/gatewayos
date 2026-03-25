---
title: "ISO 27003 ISMS Implementation Guidance — API Gateway"
iso_ref: "ISO/IEC 27003:2017 (Information security management systems — Guidance)"
version: "1.0"
status: Active
last_review: 2026-03-25
owner: ISMS Owner
classification: Internal
---

# ISO 27003 — ISMS Implementation Guidance

> Maps ISO/IEC 27003:2017 guidance to the concrete implementation of the API Gateway ISMS.
> ISO 27003 provides guidance on implementing ISO 27001 requirements (Clauses 4-10).

## 1. Context of the Organization (27003 Cl. 4)

### 4.1 Understanding the Organization and Its Context

**ISO 27003 Guidance:** Determine external and internal issues. Consider regulatory, competitive, technological factors. Use tools like PESTLE, SWOT.

**Gateway Implementation:**
- **External issues analysis:** `isms/scope-statement.md` §2.1 — BACEN regulations, LGPD, PIX/SPI, ISO 20022, competitive landscape
- **Internal issues analysis:** `isms/scope-statement.md` §2.2 — KrakenD 2.7 stack, microservices architecture, K8s, Keycloak, team competency
- **Method used:** Tabular analysis (issues → relevance mapping)
- **Review trigger:** Regulatory changes, architecture changes, team changes

### 4.2 Understanding the Needs and Expectations of Interested Parties

**ISO 27003 Guidance:** Identify interested parties. Determine their requirements. Determine which requirements the ISMS will address.

**Gateway Implementation:**
- **Register:** `isms/interested-parties.md` — 10 parties identified
- **Key parties:** BACEN (regulatory), ANPD (privacy), clients (SLA), auditors (evidence)
- **Communication plan:** Per-party channel, frequency, owner
- **LGPD-specific:** Data subjects identified; gateway transit-only (no PII storage)

### 4.3 Determining the Scope of the ISMS

**ISO 27003 Guidance:** Consider internal/external issues, interested party requirements, interfaces and dependencies. Document boundaries.

**Gateway Implementation:**
- **Scope document:** `isms/scope-statement.md`
- **In scope:** KrakenD, Envoy, Redis integration, Nginx Ingress, K8s manifests, CI/CD, monitoring
- **Out of scope:** Backend internals, Keycloak admin, CSP physical infra, end-user devices, DNS
- **Interfaces:** 7 documented interfaces with security controls mapped (§3.3)
- **Justification:** Each exclusion has documented reason and delegation target

### 4.4 Information Security Management System

**ISO 27003 Guidance:** Establish, implement, maintain, and continually improve ISMS processes and their interactions.

**Gateway Implementation:**
- **ISMS Manual:** `isms/isms-manual.md` — PDCA cycle, process interactions diagram
- **Process map:** 5 ISMS processes: risk management, performance evaluation, internal audit, management review, continual improvement
- **Integration:** Sub-ISMS of LedgerOS platform ISMS (shared policies, separate risk register)
- **Tooling:** Compliance-as-code via Git + CI + Prometheus

## 2. Leadership (27003 Cl. 5)

### 5.1 Leadership and Commitment

**ISO 27003 Guidance:** Top management must demonstrate commitment through policy, resources, roles, communication, and continual improvement support.

**Gateway Implementation:**
- **Demonstrated through:** B1-GW policy §6 commitments (5 explicit commitments)
- **Resources:** Dedicated Security Architect and DevSecOps Lead roles
- **Communication:** CLAUDE.md security section, PR review process
- **Improvement:** Corrective actions register, management review quarterly

### 5.2 Policy

**ISO 27003 Guidance:** Policy must be appropriate, include objectives, be documented, communicated, and available.

**Gateway Implementation:**
- **Document:** `isms/information-security-policy.md` (B1-GW)
- **Objectives:** 14 CIA objectives with measurable targets (§3.1-3.3)
- **Principles:** 5 principles (defense-in-depth, zero trust, least privilege, fail secure, audit everything)
- **Communication:** Git repository (all team), CLAUDE.md (developers)
- **Review:** 6-month cycle documented in frontmatter

### 5.3 Organizational Roles, Responsibilities and Authorities

**ISO 27003 Guidance:** Assign and communicate roles. Ensure ISMS conformity reporting.

**Gateway Implementation:**
- **RACI matrix:** `isms/roles-responsibilities.md` — 5 roles × all clauses
- **Segregation:** 5 conflict pairs documented with mitigation
- **Reporting:** Security Architect → ISMS Owner → Management (quarterly review)

## 3. Planning (27003 Cl. 6)

### 6.1 Actions to Address Risks and Opportunities

**ISO 27003 Guidance:** Risk assessment methodology, risk register, risk treatment plan, Statement of Applicability.

**Gateway Implementation:**
- **Methodology:** `risk/risk-methodology.md` — 5x5 matrix, 4 risk levels, 5 appetite categories
- **Risk register:** `risk/risk-register.md` — 17 risks with STRIDE mapping, scores, owners, treatment
- **Treatment plan:** Integrated in risk register — per-risk actions with target dates and evidence
- **SoA:** `risk/statement-of-applicability.md` — 93 controls: 48 implemented, 9 partial, 4 planned, 32 N/A

### 6.1.2 Risk Assessment Process

**ISO 27003 Guidance:** Define criteria for accepting risks and performing risk assessments. Ensure reproducible results.

**Gateway Implementation:**
- **Criteria:** `risk/risk-methodology.md` §3 — Likelihood (1-5), Impact (1-5 across 5 categories), Risk appetite per category
- **Process:** 5 steps: identify (STRIDE + vulnerability + incident history) → analyze (L × I) → evaluate (vs. appetite) → treat → monitor
- **Reproducibility:** Documented scales, scoring criteria, and examples
- **Threat model:** `risk/threat-model.md` — 26 STRIDE threats as systematic input

### 6.1.3 Risk Treatment

**ISO 27003 Guidance:** Select treatment options (mitigate, accept, transfer, avoid). Select controls from Annex A. Produce SoA with justification.

**Gateway Implementation:**
- **Treatment options:** 4 options used (risk register §Treatment Plan)
- **Control selection:** Controls selected from Annex A based on risk treatment needs
- **SoA:** 93 controls with applicability, status, justification for exclusion
- **Residual risk:** Documented in risk register §Residual Risk Summary (0 critical, 2 high, 4 medium)

### 6.2 Information Security Objectives and Planning to Achieve Them

**ISO 27003 Guidance:** Objectives must be measurable, monitored, communicated, updated. Plan what, resources, who, when, how to evaluate.

**Gateway Implementation:**
- **Objectives:** B1-GW §3 — 14 objectives across CIA with measurable targets
- **Measurement:** `metrics/security-metrics-framework.md` — 25 KPIs mapped to objectives
- **Monitoring:** Prometheus + OTel + CI compliance checks
- **Evaluation:** Quarterly management review

### 6.3 Planning of Changes

**ISO 27003 Guidance:** Changes to ISMS must be planned and carried out in a controlled manner.

**Gateway Implementation:**
- **Change process:** `operations/change-management.md` — 3 categories (standard/normal/emergency)
- **ISMS changes:** Policy/scope changes require ISMS Owner approval, tracked in Git

## 4. Support (27003 Cl. 7)

### 7.1 Resources

**Gateway Implementation:**
- **Compute:** K8s resources defined (CPU/memory requests/limits)
- **Human:** 5 ISMS roles assigned
- **Tooling:** Prometheus, OTel, CI/CD, Git, cert-manager

### 7.2 Competence

**Gateway Implementation:**
- **Required competence:** Documented per role in RACI
- **Evidence:** CODEOWNERS ensures qualified reviewers
- **Gap:** Formal training program planned (CA in corrective actions)

### 7.3 Awareness

**Gateway Implementation:**
- **CLAUDE.md:** Security section with ISO compliance guidance
- **PR reviews:** Security context shared through review comments
- **Gap:** Formal awareness program planned

### 7.4 Communication

**Gateway Implementation:**
- **Internal:** `isms/interested-parties.md` §3 Communication Plan
- **External:** BACEN (24h incident notification), ANPD (72h breach notification)
- **Channels:** Slack, email, Git PRs, management review meetings

### 7.5 Documented Information

**ISO 27003 Guidance:** Create, update, and control documented information required by the ISMS.

**Gateway Implementation:**
- **Creation:** All docs use consistent frontmatter (title, iso_ref, version, status, owner, classification)
- **Version control:** Git — all changes tracked, reviewable, reversible
- **Access control:** Repository permissions, classification labels
- **Retention:** Git history (indefinite), docs follow review cycle
- **Document map:** `isms/isms-manual.md` §3 — complete document index

## 5. Operation (27003 Cl. 8)

### 8.1 Operational Planning and Control

**ISO 27003 Guidance:** Plan, implement, and control processes needed to meet ISMS requirements.

**Gateway Implementation:**
- **Operational procedures:** `operations/runbooks/` — 5 runbooks (deploy, rollback, scale, key-rotation, token-revocation)
- **Change control:** `operations/change-management.md`
- **CI/CD automation:** Config validation, compliance checks, auto-deployment
- **Outsourced processes:** Backend services via mTLS, health monitoring

### 8.2 Information Security Risk Assessment

**Gateway Implementation:**
- **Frequency:** Quarterly review (minimum), triggered by significant changes
- **Last assessment:** 2026-03-25 (risk register v1.0)
- **Next assessment:** 2026-06-25

### 8.3 Information Security Risk Treatment

**Gateway Implementation:**
- **Treatment plan:** Integrated in `risk/risk-register.md`
- **Open actions:** CA-003 (SBOM/Trivy), CA-004 (Redis HA) — due 2026-Q2
- **Closed actions:** CA-001 (RBAC fix), CA-002 (bloom filter FPR)

## 6. Performance Evaluation (27003 Cl. 9)

### 9.1 Monitoring, Measurement, Analysis and Evaluation

**ISO 27003 Guidance:** Determine what to monitor/measure, methods, when, who analyzes, who reports.

**Gateway Implementation:**
- **Framework:** `metrics/security-metrics-framework.md` — 25 KPIs across 5 categories
- **Collection:** Prometheus (15s), OTel (10s), CI (per-commit), CronJob (daily)
- **Analysis:** Grafana dashboards, trend analysis
- **Reporting:** Real-time dashboards, weekly summary, monthly SLA, quarterly review

### 9.2 Internal Audit

**Gateway Implementation:**
- **Procedure:** `operations/internal-audit-procedure.md`
- **Frequency:** Annual (minimum)
- **Method:** Checklist against controls matrix + technical verification
- **Auditor:** Compliance Officer (independent of operations)

### 9.3 Management Review

**Gateway Implementation:**
- **Template:** `metrics/management-review-template.md`
- **Frequency:** Quarterly
- **Inputs:** Actions status, changes, performance (KPIs), audit results, risk updates, improvement opportunities
- **Outputs:** Decisions, resource allocation, ISMS changes

## 7. Improvement (27003 Cl. 10)

### 10.1 Nonconformity and Corrective Action

**Gateway Implementation:**
- **Register:** `operations/corrective-actions.md` — 4 initial entries (2 closed, 2 open)
- **Process:** Identify → analyze (5-Whys) → plan → implement → verify → close
- **Evidence:** Git commits linked to corrective actions

### 10.2 Continual Improvement

**Gateway Implementation:**
- **Sources:** Incidents, audits, metrics trends, regulatory changes, technology updates
- **Mechanism:** Corrective actions register + management review decisions
- **Tracking:** Git history shows ISMS evolution over time

---

## ISO 27003 Compliance Summary

| ISO 27003 Section | ISO 27001 Clause | Gateway Document | Status |
|-------------------|-----------------|------------------|--------|
| 4.1 Context | Cl. 4.1 | `isms/scope-statement.md` §2 | Complete |
| 4.2 Interested Parties | Cl. 4.2 | `isms/interested-parties.md` | Complete |
| 4.3 Scope | Cl. 4.3 | `isms/scope-statement.md` §3 | Complete |
| 4.4 ISMS | Cl. 4.4 | `isms/isms-manual.md` | Complete |
| 5.1 Leadership | Cl. 5.1 | `isms/information-security-policy.md` §6 | Complete |
| 5.2 Policy | Cl. 5.2 | `isms/information-security-policy.md` | Complete |
| 5.3 Roles | Cl. 5.3 | `isms/roles-responsibilities.md` | Complete |
| 6.1 Risk | Cl. 6.1 | `risk/risk-methodology.md`, `risk/risk-register.md`, `risk/statement-of-applicability.md` | Complete |
| 6.2 Objectives | Cl. 6.2 | B1-GW §3 + `metrics/security-metrics-framework.md` | Complete |
| 6.3 Change | Cl. 6.3 | `operations/change-management.md` | Complete |
| 7.1-7.4 Support | Cl. 7 | RACI, CLAUDE.md, interested-parties comm plan | Complete |
| 7.5 Documentation | Cl. 7.5 | `isms/isms-manual.md` §3 document map | Complete |
| 8.1-8.3 Operation | Cl. 8 | Runbooks, risk assessment/treatment | Complete |
| 9.1 Monitoring | Cl. 9.1 | `metrics/security-metrics-framework.md` | Complete |
| 9.2 Internal Audit | Cl. 9.2 | `operations/internal-audit-procedure.md` | Complete |
| 9.3 Management Review | Cl. 9.3 | `metrics/management-review-template.md` | Complete |
| 10.1-10.2 Improvement | Cl. 10 | `operations/corrective-actions.md` | Complete |

**All 17 ISO 27003 guidance areas covered.**

---

> **Cross-references:** [ISMS Manual](isms-manual.md) | [Controls Matrix](../compliance/controls-matrix.md) | [ISO 27003 source PDF](ledgeros/.base/knowledge/iso-27000/pdfs/ISO_IEC_27003_2017(en).pdf)
