---
title: "Interested Parties Register — API Gateway"
iso_ref: ISO/IEC 27001:2022 Clause 4.2
version: "1.0"
status: Approved
last_review: 2026-03-25
next_review: 2026-09-25
classification: Internal
---

# Interested Parties Register — API Gateway

## 1. Purpose

Identifies parties with an interest in the API Gateway's information security, their requirements, and how the ISMS addresses them (ISO 27001 Cl. 4.2).

## 2. Register

| # | Interested Party | Type | Requirements | ISMS Response | Addressed By |
|---|-----------------|------|-------------|---------------|--------------|
| 1 | **BACEN** (Central Bank of Brazil) | Regulator | Res. 4.893/2021: cybersecurity policy, incident notification within 24h; CMN 4.658/2018: cloud security controls | Security policy (B1-GW), IRP with BACEN notification procedure, K8s security controls | Cl. 5.2, A.5.24-26, A.8.20 |
| 2 | **ANPD** (National Data Protection Authority) | Regulator | LGPD compliance: PII minimization, consent, breach notification 72h | DLP Lua plugin, data masking in logs, PII stripping in responses | A.5.34, A.8.11, A.8.12 |
| 3 | **Client financial institutions** (banks, fintechs) | Customer | ISO 27001 certification, contractual SLAs (99.9% uptime), data confidentiality, audit rights | ISMS certification, SLA monitoring, mTLS, audit trail access | A.5.14, A.8.24, A.8.14 |
| 4 | **External auditors** | Assessor | Evidence of control implementation, audit trail integrity, access to documentation | Controls matrix, immutable audit logs, evidence collection procedure | A.5.35, A.5.28, A.8.15 |
| 5 | **Development team** | Internal | Clear security policies, secure development guidelines, security tooling | B1-GW policy, secure config guidelines, CI security gates, CLAUDE.md | A.8.25, A.8.28, A.6.3 |
| 6 | **Operations team** | Internal | Runbooks, monitoring dashboards, incident procedures, change management | Runbooks, Grafana dashboards, IRP, change management procedure | A.5.37, A.8.16, A.8.32 |
| 7 | **Data subjects** (end users via LGPD) | Legal | PII protection, right to access/delete, data portability | Gateway does not store PII; transit-only protection via TLS, log masking | A.5.34, A.8.24 |
| 8 | **Cloud service providers** (GCP/K8s) | Supplier | Shared responsibility model compliance, SLA adherence | K8s security context, network policies, resource limits | A.5.23, A.8.20, A.8.22 |
| 9 | **Third-party integrations** (Keycloak, Redis, Envoy) | Supplier | Version compliance, security patches, configuration security | Pinned versions, vulnerability scanning in CI, security configs | A.5.19, A.8.8, A.8.19 |
| 10 | **Management / Board** | Governance | ISMS effectiveness reporting, risk posture, compliance status | Management review (quarterly), security metrics dashboard, risk register | Cl. 5.1, Cl. 9.3 |

## 3. Communication Plan

| Party | What | When | Channel | Owner |
|-------|------|------|---------|-------|
| BACEN | Incident notification | Within 24h of incident | Regulatory portal | Compliance Officer |
| ANPD | Data breach notification | Within 72h of breach | ANPD portal | Compliance Officer |
| Clients | SLA reports, security posture | Monthly | Client portal / email | ISMS Owner |
| Auditors | Evidence packages | During audit cycle | Document share | Compliance Officer |
| Dev team | Policy updates, security advisories | As needed | Slack #security, Git PRs | Security Architect |
| Ops team | Runbook updates, alert changes | As needed | Slack #ops, Git PRs | DevSecOps Lead |
| Management | ISMS performance report | Quarterly | Management review meeting | ISMS Owner |

## 4. Review Triggers

This register is reviewed when:
- New regulatory requirements are issued
- New client contracts include security requirements
- Organizational structure changes
- Significant changes to the gateway architecture
- At minimum every 6 months

## 5. Document Control

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | 2026-03-25 | Compliance Officer | Initial register |
