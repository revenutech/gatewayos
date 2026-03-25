---
title: "ISO 27002:2022 Organizational Controls Implementation Guide — API Gateway"
iso_ref: "ISO/IEC 27002:2022 Clause 5 (Controls 5.1-5.37)"
version: "1.0"
status: Active
last_review: 2026-03-25
owner: Compliance Officer
classification: Internal
---

# ISO 27002 — Organizational Controls (A.5) Implementation Guide

> 37 controls. Implementation guidance from ISO 27002:2022 mapped to concrete gateway artifacts.
> Attributes: Control Type | CIA Properties | Cybersecurity Concept | Operational Capability | Security Domain

## 5.1 Policies for Information Security

| Attribute | Value |
|-----------|-------|
| Type | Preventive |
| CIA | C, I, A |
| Concept | Identify |
| Capability | Governance |
| Domain | Governance & Ecosystem, Resilience |

**ISO 27002 Guidance:** Define policy approved by top management with statements on objectives, principles, commitment, responsibilities. Support with topic-specific policies. Review at planned intervals.

**Gateway Implementation:**
- **Policy:** `isms/information-security-policy.md` (B1-GW) — approved by ISMS Owner
- **Topic-specific policies:** Access control (JWT/RBAC config), rate limiting, CORS, security headers, mTLS
- **Review cycle:** Every 6 months or on significant change (frontmatter `next_review`)
- **Communication:** CLAUDE.md links to all policies, PR review ensures awareness

## 5.2 Information Security Roles and Responsibilities

| Attribute | Value |
|-----------|-------|
| Type | Preventive |
| CIA | C, I, A |
| Concept | Identify |
| Capability | Governance |
| Domain | Governance & Ecosystem, Protection, Resilience |

**ISO 27002 Guidance:** Define and allocate roles. Document responsibilities. Ensure competence.

**Gateway Implementation:**
- **RACI matrix:** `isms/roles-responsibilities.md` — 5 roles across all ISO clauses
- **CODEOWNERS:** Security Architect review required for security-impacting files
- **Segregation:** Developer ≠ deployer, config author ≠ approver, auditor ≠ auditee

## 5.3 Segregation of Duties

| Attribute | Value |
|-----------|-------|
| Type | Preventive |
| CIA | C, I, A |
| Concept | Protect |
| Capability | Governance, IAM |
| Domain | Governance & Ecosystem |

**ISO 27002 Guidance:** Separate conflicting duties. Use monitoring/audit trails where full segregation is difficult.

**Gateway Implementation:**
- **PR reviews:** No self-merge; CODEOWNERS enforces reviewer ≠ author
- **CI/CD deploys:** Developers don't deploy directly; CI pipeline auto-deploys on merge
- **Audit:** Compliance Officer audits, DevSecOps operates (separate concerns)
- **Cert management:** cert-manager manages keys; KrakenD only reads (read-only mount)
- **Evidence:** `isms/roles-responsibilities.md` §3 Segregation of Duties table

## 5.7 Threat Intelligence

| Attribute | Value |
|-----------|-------|
| Type | Preventive, Detective, Corrective |
| CIA | C, I, A |
| Concept | Identify, Detect, Respond |
| Capability | Threat & vulnerability management |
| Domain | Defence, Resilience |

**ISO 27002 Guidance:** Collect and analyze threat information. Produce actionable intelligence.

**Gateway Implementation:**
- **STRIDE threat model:** `risk/threat-model.md` — 26 threats across 6 categories
- **CVE monitoring:** CI image scanning (planned Trivy), KrakenD release tracking
- **Runtime detection:** PrometheusRules detect auth spikes, DDoS patterns, CB trips
- **Blocklists:** `lua/web_filter.lua` (SSRF), `lua/security_policies.lua` (UA blocking)

## 5.8 Information Security in Project Management

| Attribute | Value |
|-----------|-------|
| Type | Preventive |
| CIA | C, I, A |
| Concept | Identify |
| Capability | Governance |
| Domain | Governance & Ecosystem |

**Gateway Implementation:**
- **ISO annotations:** All config files include Annex A control references
- **CI security gates:** Config validation, compliance check, audit on every PR
- **CLAUDE.md:** Security section guides development decisions
- **Evidence:** `.github/workflows/compliance.yml`

## 5.9 Inventory of Information and Other Associated Assets

**Gateway Implementation:**
- **Asset inventory:** `isms/scope-statement.md` §3.1 — all assets categorized
- **Service map:** `krakend/settings/service_routes.json` — all backends
- **Configuration assets:** `krakend/` directory structure (fully documented in CLAUDE.md)

## 5.12 Classification of Information

**Gateway Implementation:**
- **Document classification:** All `.base/docs` files have `classification:` frontmatter (Public/Internal/Confidential)
- **API data classification:** PII never stored; transit-only protection via TLS
- **Log classification:** Prod logs at WARNING level (no sensitive data)

## 5.14 Information Transfer

| Attribute | Value |
|-----------|-------|
| Type | Preventive |
| CIA | C, I, A |
| Concept | Protect |
| Capability | Information protection, Asset management |
| Domain | Protection |

**ISO 27002 Guidance:** Implement transfer rules for all types of transfer. Use encryption. Maintain confidentiality.

**Gateway Implementation:**
- **External → Gateway:** TLS 1.2+ via Nginx Ingress (`ingress.yaml`: `ssl-redirect: true`)
- **Gateway → Backends:** mTLS (`mtls_backend.tmpl`, `mtls-certificates.yaml`)
- **Gateway → Redis:** NetworkPolicy restricted (`krakend-egress.yaml`)
- **Gateway → Keycloak:** TLS (prod), HTTP only in dev with `disable_jwk_security: true`
- **Cipher suites:** ECDHE-RSA-AES-256-GCM, ECDHE-RSA-AES-128-GCM, AES-256-GCM, AES-128-GCM

## 5.15 Access Control

**ISO 27002 Guidance:** Establish and implement rules for physical and logical access based on business and security requirements.

**Gateway Implementation:**
- **Logical access:** JWT RBAC per endpoint (`jwt_validator.tmpl`, `auth/validator` in every endpoint)
- **Role hierarchy:** `ledger-viewer` (read) < `ledger-operator` (write) < `ledger-admin` (all)
- **Tenant isolation:** CEL policies enforce `X-Tenant-ID` (`security/policies.json`)
- **API key auth:** Alternative to JWT for M2M (`lua/api_key_auth.lua`)
- **Network access:** NetworkPolicies (ingress/egress explicit allow)

## 5.16 Identity Management

**Gateway Implementation:**
- **Identity provider:** Keycloak (external) via JWKS
- **Claims propagation:** `sub` → X-User-ID, `tenant_id` → X-Tenant-ID, `roles` → X-Roles, `jti` → X-JWT-JTI
- **API key identities:** `apikey:<id>` format, scoped to tenant/roles

## 5.17 Authentication Information

**ISO 27002 Guidance:** Control allocation and management of authentication info. Advise on handling.

**Gateway Implementation:**
- **JWT:** RS256 via JWKS, cached 1h, `failed_jwk_key_cooldown: 10s`
- **DPoP:** Token binding to client key pair (`security/dpop.tmpl`) — RFC 9449
- **PAR:** Pushed Authorization Requests (`security/par.tmpl`) — RFC 9126
- **Token revocation:** 3 levels (token, user, tenant) via Redis + bloom filter
- **API keys:** Config-based registry, per-tenant scoped, disable capability

## 5.18 Access Rights

**Gateway Implementation:**
- **Provisioning:** Keycloak realm roles → JWT claims → KrakenD RBAC
- **Review:** `roles_key_is_nested: true` ensures correct Keycloak nested role parsing
- **Modification:** Role changes in Keycloak take effect on next JWT issuance
- **Removal:** Token revocation (immediate), role removal in Keycloak (next auth)

## 5.21 Managing Information Security in the ICT Supply Chain

**Gateway Implementation:**
- **Image pinning:** `krakend:2.7`, `envoy:v1.31-latest` in deployment/Dockerfile
- **Planned:** SBOM generation, Trivy image scanning in CI (CA-003)
- **Minimal dependencies:** KrakenD CE + Envoy (well-known, audited projects)

## 5.22 Monitoring, Review and Change Management of Supplier Services

**Gateway Implementation:**
- **Backend health:** `endpoints/health.json` (/__health, /__ready)
- **Aggregated health:** `endpoints/dashboard_v1.json` — 5 backends in one call
- **Prometheus alerts:** CB open, high error rate, high latency

## 5.24-5.28 Incident Management

**Gateway Implementation:**
- **5.24 Planning:** `operations/incident-response-plan.md` — 4 severity levels, procedures
- **5.25 Assessment:** 12 PrometheusRules classify events by severity
- **5.26 Response:** IRP containment procedures (token revocation, IP block, rollback)
- **5.27 Learning:** Post-mortem process, `operations/corrective-actions.md`
- **5.28 Evidence:** `lua/audit_evidence.lua` hash chain, structured logs, OTel traces

## 5.29-5.30 Business Continuity

**Gateway Implementation:**
- **5.29 During disruption:** Circuit breakers, PDB, graceful 503 + Retry-After
- **5.30 ICT readiness:** HPA 2-8 pods, anti-affinity, rolling updates, `operations/business-continuity-plan.md`

## 5.31 Legal, Statutory, Regulatory and Contractual Requirements

**Gateway Implementation:**
- **BACEN:** Res. 4.893/2021, CMN 4.658/2018 mapped in B1-GW §5
- **LGPD:** PII transit-only, DLP plugin, log sanitization
- **Interested parties:** `isms/interested-parties.md` with 10 parties

## 5.33 Protection of Records

**Gateway Implementation:**
- **Git history:** Immutable, auditable change record
- **Audit logs:** Hash chain (`lua/audit_evidence.lua`), structured JSON
- **Data retention:** `compliance/data-retention-policy.md` — 90d access logs, 1yr audit

## 5.34 Privacy and Protection of PII

**Gateway Implementation:**
- **DLP plugin:** `lua/dlp.lua` strips PII from responses (CPF masking, card masking)
- **Log sanitization:** Prod WARNING level, no tokens/PII in logs
- **Transit-only:** Gateway stores no PII; data flows through encrypted channels

## 5.36 Compliance with Policies, Rules and Standards

**Gateway Implementation:**
- **CI compliance:** `.github/workflows/compliance.yml` — 6 automated checks
- **Config audit:** `tools/config-audit/audit.sh` — env consistency, security, CORS, rate limits
- **Internal audit:** `operations/internal-audit-procedure.md`

## 5.37 Documented Operating Procedures

**Gateway Implementation:**
- **Runbooks:** `operations/runbooks/` — deploy, rollback, scale, key-rotation, token-revocation
- **Change management:** `operations/change-management.md`
- **CI documentation:** `.github/workflows/ci.yml`, `.github/workflows/compliance.yml`

---

## Controls Not Applicable to Gateway (Delegated)

| Control | Reason | Delegated To |
|---------|--------|-------------|
| 5.4 Management responsibilities | Organizational level | LedgerOS ISMS |
| 5.5 Contact with authorities | Organizational level | Compliance Officer |
| 5.6 Contact with special interest groups | Organizational level | Management |
| 5.10 Acceptable use | Organizational level | LedgerOS B1-ISP |
| 5.11 Return of assets | HR process | HR |
| 5.13 Labelling | Partial (frontmatter only) | Expanding |
| 5.19-5.20 Supplier relationships | Organizational level | Procurement |
| 5.23 Cloud services | Infrastructure level | Platform team |
| 5.25 Independent review | External audit | External auditor |
| 5.32 Intellectual property | Legal process | Legal |

---

## ISO 27002:2022 Attribute Table — All Applicable Organizational Controls

| # | Control | Type | CIA | Cybersecurity Concept | Operational Capability | Security Domain |
|---|---------|------|-----|----------------------|----------------------|----------------|
| 5.1 | Policies | Preventive | C,I,A | Identify | Governance | Governance, Resilience |
| 5.2 | Roles & responsibilities | Preventive | C,I,A | Identify | Governance | Governance, Protection, Resilience |
| 5.3 | Segregation of duties | Preventive | C,I,A | Protect | Governance, IAM | Governance |
| 5.7 | Threat intelligence | Preventive, Detective, Corrective | C,I,A | Identify, Detect, Respond | Threat & vulnerability mgmt | Defence, Resilience |
| 5.8 | Security in project mgmt | Preventive | C,I,A | Identify | Governance | Governance |
| 5.9 | Inventory of assets | Preventive | C,I,A | Identify | Asset management | Governance, Protection |
| 5.12 | Classification | Preventive | C,I,A | Identify | Information protection | Governance, Protection |
| 5.14 | Information transfer | Preventive | C,I,A | Protect | Asset mgmt, Info protection | Protection |
| 5.15 | Access control | Preventive | C,I,A | Protect | IAM | Protection |
| 5.16 | Identity management | Preventive | C,I,A | Protect | IAM | Protection |
| 5.17 | Authentication info | Preventive | C,I,A | Protect | IAM | Protection |
| 5.18 | Access rights | Preventive | C,I,A | Protect | IAM | Protection |
| 5.21 | ICT supply chain | Preventive | C,I,A | Identify | Supplier security | Governance, Protection |
| 5.22 | Monitoring suppliers | Detective | C,I,A | Detect | Supplier security | Defence |
| 5.24 | Incident planning | Corrective | C,I,A | Respond | Incident management | Defence |
| 5.25 | Assessment of events | Detective | C,I,A | Detect | Incident management | Defence |
| 5.26 | Response to incidents | Corrective | C,I,A | Respond | Incident management | Defence |
| 5.27 | Learning from incidents | Preventive | C,I,A | Identify | Incident management | Defence |
| 5.28 | Evidence collection | Detective | C,I,A | Detect, Respond | Incident management | Defence |
| 5.29 | Security during disruption | Preventive, Corrective | C,I,A | Protect, Recover | Continuity | Resilience |
| 5.30 | ICT readiness for BC | Corrective | A | Recover | Continuity | Resilience |
| 5.31 | Legal requirements | Preventive | C,I,A | Identify | Legal & compliance | Governance |
| 5.33 | Protection of records | Preventive | C,I,A | Protect | Legal & compliance, Asset mgmt | Defence |
| 5.34 | Privacy and PII | Preventive | C | Identify, Protect | Information protection | Protection |
| 5.36 | Compliance with policies | Preventive, Detective | C,I,A | Identify, Protect | Legal & compliance | Governance |
| 5.37 | Operating procedures | Preventive | C,I,A | Protect | Asset mgmt, Physical security | Protection |

> **Cross-references:** [Controls Matrix](controls-matrix.md) | [SoA](../risk/statement-of-applicability.md) | [ISO 27002 source](ledgeros/.base/knowledge/iso-27002/)
