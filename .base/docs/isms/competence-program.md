---
title: "Competence Program — API Gateway ISMS"
iso_ref: "ISO/IEC 27001:2022 Clause 7.2, ISO/IEC 27002:2022 A.6.3"
version: "1.0"
status: Active
last_review: 2026-03-25
next_review: 2026-09-25
owner: ISMS Owner
classification: Internal
---

# Competence Program — API Gateway ISMS

## 1. Purpose

Defines the competence requirements for each ISMS role, how competence is determined, and what actions are taken to address gaps (ISO 27001 Cl. 7.2).

## 2. Competence Matrix

### 2.1 ISMS Owner

| Competence Area | Required Level | Evidence Type | Verification |
|----------------|---------------|---------------|--------------|
| ISO 27001:2022 framework | Expert | Certification (ISO 27001 Lead Implementer or equivalent) | Certificate on file |
| Risk management (ISO 27005) | Advanced | Training record + practical experience | Risk register quality review |
| Regulatory knowledge (BACEN, LGPD) | Advanced | Training + regulatory updates tracking | Regulatory mapping accuracy |
| Management systems (Annex SL) | Intermediate | Training record | Management review quality |
| API Gateway architecture | Basic | On-the-job briefing | Scope statement accuracy |

### 2.2 Security Architect

| Competence Area | Required Level | Evidence Type | Verification |
|----------------|---------------|---------------|--------------|
| API security (OWASP API Top 10) | Expert | Training + practical experience | Threat model quality |
| KrakenD configuration | Expert | Hands-on experience (6+ months) | Config review quality |
| JWT/OAuth 2.0/OIDC | Expert | Training + implementation evidence | Auth config correctness |
| TLS/mTLS/Cryptography | Advanced | Training record | Cipher suite selection review |
| Kubernetes security | Advanced | CKS certification or equivalent | K8s manifest security review |
| ISO 27001 Annex A controls | Advanced | Training record | Controls matrix accuracy |
| Threat modeling (STRIDE) | Advanced | Training + practical application | Threat model completeness |

### 2.3 DevSecOps Lead

| Competence Area | Required Level | Evidence Type | Verification |
|----------------|---------------|---------------|--------------|
| Kubernetes operations | Expert | CKA/CKS or equivalent experience | Deployment management quality |
| CI/CD security | Advanced | Pipeline implementation evidence | CI pipeline effectiveness |
| Monitoring (Prometheus, OTel) | Advanced | Hands-on experience | Alert quality, dashboard coverage |
| Incident response | Advanced | IRP training + drills | Drill performance review |
| Certificate management (cert-manager) | Intermediate | Hands-on experience | Cert rotation success rate |
| Container security | Advanced | Training record | Image security practices |

### 2.4 Compliance Officer

| Competence Area | Required Level | Evidence Type | Verification |
|----------------|---------------|---------------|--------------|
| ISO 27001:2022 auditing | Expert | ISO 27001 Lead Auditor certification | Certificate on file |
| ISO 19011 audit methodology | Advanced | Training record | Audit report quality |
| BACEN regulations | Expert | Regulatory training record | Compliance mapping accuracy |
| LGPD / Data protection | Advanced | DPO training or equivalent | Privacy control review |
| Evidence management | Advanced | Practical experience | Evidence package completeness |

### 2.5 Gateway Developer

| Competence Area | Required Level | Evidence Type | Verification |
|----------------|---------------|---------------|--------------|
| KrakenD Flexible Configuration | Intermediate | Hands-on training | Config contributions |
| Lua scripting (KrakenD plugins) | Intermediate | Code review evidence | Plugin code quality |
| Secure coding practices | Intermediate | OWASP training record | Security-impacting PR quality |
| ISO 27001 awareness | Basic | Awareness training completion | Acknowledgment record |
| Git workflow & code review | Intermediate | Contribution history | PR review participation |

## 3. Competence Verification Process

### 3.1 Initial Assessment
1. **On hiring/role assignment:** Manager verifies competence against matrix above
2. **Gap identification:** Compare actual competence vs. required level
3. **Action plan:** Training, mentoring, or reassignment if gaps are critical
4. **Record:** Competence assessment stored in HR records (external to gateway ISMS)

### 3.2 Ongoing Verification
| Method | Frequency | Applies To |
|--------|-----------|-----------|
| Performance review | Annual | All roles |
| Certification validity check | Annual | ISMS Owner, Compliance Officer |
| Drill/exercise evaluation | Quarterly | DevSecOps Lead (incident response) |
| PR review quality assessment | Quarterly | Security Architect, Developers |
| Training record update | After each training | All roles |

### 3.3 Competence Actions

| Gap Type | Action | Timeline | Evidence |
|----------|--------|----------|----------|
| Missing certification | Enroll in certification program | 6 months | Certificate |
| Insufficient hands-on | Pair with experienced team member | 3 months | Mentor sign-off |
| Knowledge gap | Assign targeted training course | 1 month | Training completion record |
| Skill atrophy | Refresher training or drill | 1 month | Assessment score |

## 4. Training Plan

### 4.1 Mandatory Training (All ISMS Roles)

| Training | Frequency | Duration | Provider |
|----------|-----------|----------|----------|
| ISO 27001:2022 fundamentals | On-boarding + annual refresh | 4 hours | Internal / e-learning |
| Security awareness (see awareness-program.md) | Quarterly | 1 hour | Internal |
| LGPD/BACEN regulatory update | Semi-annual | 2 hours | Legal / Compliance |
| Gateway architecture overview | On-boarding | 2 hours | Security Architect |

### 4.2 Role-Specific Training

| Role | Training | Frequency |
|------|----------|-----------|
| ISMS Owner | ISO 27001 Lead Implementer | Every 3 years (cert renewal) |
| Security Architect | OWASP API Security, CKS | Annual |
| DevSecOps Lead | Incident response drill, CKA/CKS | Annual / Quarterly drills |
| Compliance Officer | ISO 27001 Lead Auditor, LGPD DPO | Every 3 years |
| Developer | Secure coding (OWASP), KrakenD workshop | Annual |

## 5. Training Records

Training records are maintained in:
- **HR system** (external): Certifications, formal training completion
- **Git repository**: Technical training evidence (PRs, code reviews, drill reports)
- **Training register** (below): Summary of completed training

### Training Register Template

| Date | Person | Role | Training | Provider | Duration | Evidence | Next Refresh |
|------|--------|------|----------|----------|----------|----------|-------------|
| | | | | | | | |

## 6. Document Control

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | 2026-03-25 | ISMS Owner | Initial competence program |
