---
title: "ISMS Roles & Responsibilities — API Gateway"
iso_ref: ISO/IEC 27001:2022 Clause 5.3, Annex A Control 5.2
version: "1.0"
status: Approved
last_review: 2026-03-25
next_review: 2026-09-25
classification: Internal
---

# ISMS Roles & Responsibilities — API Gateway

## 1. Security Roles

### 1.1 ISMS Owner
- **Accountability:** Overall ISMS effectiveness for the Gateway
- **Authority:** Approve policies, accept residual risk, authorize security expenditures
- **Responsibilities:**
  - Ensure ISMS conformity with ISO 27001:2022
  - Report ISMS performance to top management (Cl. 5.3b)
  - Authorize Statement of Applicability
  - Chair management reviews (Cl. 9.3)

### 1.2 Security Architect
- **Accountability:** Technical security design and implementation
- **Authority:** Approve architectural changes, define security patterns
- **Responsibilities:**
  - Design and maintain defense-in-depth architecture
  - Define JWT/RBAC/mTLS configurations
  - Review security-impacting PRs
  - Maintain threat model (ISO 27005)
  - Define security metrics (ISO 27004)

### 1.3 DevSecOps Lead
- **Accountability:** Security automation and operational security
- **Authority:** Approve CI/CD pipeline changes, manage security tooling
- **Responsibilities:**
  - Maintain CI/CD security gates (config validation, compliance checks)
  - Operate monitoring and alerting (Prometheus, OTel)
  - Manage certificate rotation (mTLS, TLS)
  - Execute incident response procedures
  - Maintain runbooks and operating procedures

### 1.4 Compliance Officer
- **Accountability:** Regulatory compliance and audit readiness
- **Authority:** Request evidence, escalate non-conformities
- **Responsibilities:**
  - Maintain controls matrix and SoA
  - Coordinate internal audits (Cl. 9.2)
  - Track corrective actions (Cl. 10.1)
  - Liaise with external auditors and regulators (BACEN, ANPD)
  - Ensure LGPD compliance for gateway-processed data

### 1.5 Gateway Developer
- **Accountability:** Secure development of gateway configurations
- **Responsibilities:**
  - Follow secure coding/configuration practices (A.8.28)
  - Include ISO annotations in all config files
  - Participate in security awareness training (A.6.3)
  - Report security events (A.6.8)

## 2. RACI Matrix

**R** = Responsible, **A** = Accountable, **C** = Consulted, **I** = Informed

| Activity | ISMS Owner | Sec Architect | DevSecOps Lead | Compliance | Developer |
|----------|:----------:|:-------------:|:--------------:|:----------:|:---------:|
| **ISO 27001 Cl. 4-5: Foundation** |
| Define ISMS scope | A | R | C | C | I |
| Approve security policy | A | R | C | C | I |
| Assign roles & responsibilities | A/R | C | C | I | I |
| **ISO 27001 Cl. 6: Planning** |
| Risk assessment | A | R | C | R | I |
| Risk treatment plan | A | R | C | C | I |
| Statement of Applicability | A | R | C | R | I |
| **ISO 27001 Cl. 7: Support** |
| Security awareness training | A | C | C | R | R |
| Document control | I | C | C | A/R | R |
| **ISO 27001 Cl. 8: Operation** |
| JWT/RBAC configuration | I | A | R | I | R |
| Rate limiting & CB config | I | A | R | I | R |
| Network policies | I | A | R | I | R |
| Certificate management | I | C | A/R | I | I |
| Incident response | A | C | R | C | R |
| Change management | I | A | R | I | R |
| **ISO 27001 Cl. 9: Evaluation** |
| Security metrics collection | I | C | A/R | C | I |
| Internal audit | A | C | C | R | C |
| Management review | A/R | R | R | R | I |
| **ISO 27001 Cl. 10: Improvement** |
| Corrective actions | A | R | R | R | R |
| Continual improvement | A | R | R | C | C |

## 3. Segregation of Duties (A.5.3)

| Conflict | Segregation |
|----------|-------------|
| Developer ↔ Deployer | PR review required before merge; CI/CD deploys, not developers |
| Config author ↔ Config approver | CODEOWNERS enforces review by Security Architect |
| Incident responder ↔ Incident investigator | DevSecOps responds, Compliance investigates root cause |
| Auditor ↔ Auditee | Internal audits conducted by Compliance, not DevSecOps |
| Key custodian ↔ Key user | cert-manager manages keys; KrakenD only reads certificates |

## 4. Document Control

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | 2026-03-25 | ISMS Owner | Initial RACI definition |
