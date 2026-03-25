---
title: "Statement of Applicability (SoA) — API Gateway"
iso_ref: "ISO/IEC 27001:2022 Clause 6.1.3d"
version: "1.0"
status: Approved
approved_by: ISMS Owner
last_review: 2026-03-25
next_review: 2026-09-25
classification: Confidential
---

# Statement of Applicability — API Gateway

## Summary

| Category | Total | Applicable | Implemented | Partial | Planned | N/A |
|----------|:-----:|:----------:|:-----------:|:-------:|:-------:|:---:|
| A.5 Organizational | 37 | 28 | 22 | 4 | 2 | 9 |
| A.6 People | 8 | 3 | 1 | 2 | 0 | 5 |
| A.7 Physical | 14 | 0 | 0 | 0 | 0 | 14 |
| A.8 Technological | 34 | 30 | 25 | 3 | 2 | 4 |
| **Total** | **93** | **61** | **48** | **9** | **4** | **32** |
| **Coverage** | | **66%** | **79% of applicable** | **15%** | **6%** | |

## A.5 — Organizational Controls

| # | Control | Applicable | Status | Justification / Evidence |
|---|---------|:----------:|--------|--------------------------|
| 5.1 | Policies for information security | Yes | Implemented | `isms/information-security-policy.md` (B1-GW) |
| 5.2 | Information security roles | Yes | Implemented | `isms/roles-responsibilities.md` (RACI) |
| 5.3 | Segregation of duties | Yes | Implemented | RACI matrix, CODEOWNERS, PR review |
| 5.4 | Management responsibilities | Yes | Implemented | B1-GW §6 commitments |
| 5.5 | Contact with authorities | No | N/A | Platform-level control (LedgerOS ISMS) |
| 5.6 | Contact with special interest groups | No | N/A | Platform-level control |
| 5.7 | Threat intelligence | Yes | Implemented | `risk/threat-model.md`, CVE monitoring in CI |
| 5.8 | Information security in project mgmt | Yes | Implemented | ISO annotations in all configs, security gates in CI |
| 5.9 | Inventory of information assets | Yes | Implemented | `isms/scope-statement.md` §3.1 asset list |
| 5.10 | Acceptable use | No | N/A | Platform-level control |
| 5.11 | Return of assets | No | N/A | HR process, not gateway-specific |
| 5.12 | Classification of information | Yes | Implemented | Document classification in frontmatter (Public/Internal/Confidential) |
| 5.13 | Labelling of information | Yes | Partial | Frontmatter classification; API response labelling planned |
| 5.14 | Information transfer | Yes | Implemented | TLS 1.2+, mTLS, `mtls_backend.tmpl`, `mtls-certificates.yaml` |
| 5.15 | Access control | Yes | Implemented | JWT RBAC per endpoint, `jwt_validator.tmpl`, `auth/validator` |
| 5.16 | Identity management | Yes | Implemented | Keycloak integration, JWT claims propagation |
| 5.17 | Authentication information | Yes | Implemented | JWT validation, API key auth, DPoP, token revocation |
| 5.18 | Access rights | Yes | Implemented | Role-based: viewer < operator < admin per endpoint |
| 5.19 | Supplier relationships | No | N/A | Platform-level control |
| 5.20 | Supplier agreements | No | N/A | Platform-level control |
| 5.21 | ICT supply chain | Yes | Partial | Pinned image versions; SBOM planned |
| 5.22 | Monitoring supplier services | Yes | Implemented | Backend health monitoring, `endpoints/health.json` |
| 5.23 | Cloud services | No | N/A | Platform-level control (K8s/cloud) |
| 5.24 | Incident management planning | Yes | Planned | `operations/incident-response-plan.md` (pending) |
| 5.25 | Assessment of security events | Yes | Implemented | PrometheusRules: 8 alert rules, severity classification |
| 5.26 | Response to incidents | Yes | Planned | IRP pending; circuit breakers provide automated response |
| 5.27 | Learning from incidents | Yes | Partial | Corrective actions register planned |
| 5.28 | Collection of evidence | Yes | Implemented | Structured access logs, Git audit trail, OTel traces |
| 5.29 | Security during disruption | Yes | Implemented | Circuit breakers, PDB, HPA, graceful degradation |
| 5.30 | ICT readiness for BC | Yes | Implemented | Multi-replica, anti-affinity, HPA 2-8 pods |
| 5.31 | Legal requirements | Yes | Implemented | BACEN/LGPD mapped in B1-GW §5 |
| 5.32 | Intellectual property rights | No | N/A | Platform-level control |
| 5.33 | Protection of records | Yes | Implemented | Immutable Git history, log retention |
| 5.34 | Privacy and PII protection | Yes | Implemented | Log sanitization, DLP planned, no PII storage |
| 5.35 | Independent review | No | N/A | Platform-level control (external audit) |
| 5.36 | Compliance with policies | Yes | Implemented | CI compliance checks, `tools/config-audit/audit.sh` |
| 5.37 | Documented operating procedures | Yes | Partial | Runbooks planned, CI documented |

## A.6 — People Controls

| # | Control | Applicable | Status | Justification / Evidence |
|---|---------|:----------:|--------|--------------------------|
| 6.1 | Screening | No | N/A | HR process, not gateway-specific |
| 6.2 | Terms and conditions | No | N/A | HR process |
| 6.3 | Security awareness & training | Yes | Partial | CLAUDE.md security guidance; formal training planned |
| 6.4 | Disciplinary process | No | N/A | HR process |
| 6.5 | After termination | No | N/A | HR process |
| 6.6 | Confidentiality agreements | No | N/A | HR/legal process |
| 6.7 | Remote working | Yes | Implemented | VPN not required (cloud-native); MFA via Keycloak |
| 6.8 | Security event reporting | Yes | Partial | Automated alerting; manual reporting channel planned |

## A.7 — Physical Controls

| # | Control | Applicable | Status | Justification |
|---|---------|:----------:|--------|---------------|
| 7.1-7.14 | All physical controls | No | N/A | Cloud-native deployment; physical security delegated to CSP per shared responsibility model. K8s runs on managed infrastructure. |

## A.8 — Technological Controls

| # | Control | Applicable | Status | Justification / Evidence |
|---|---------|:----------:|--------|--------------------------|
| 8.1 | User endpoint devices | No | N/A | Gateway has no user endpoints; API-only |
| 8.2 | Privileged access rights | Yes | Implemented | K8s RBAC, non-root containers, dropped capabilities |
| 8.3 | Information access restriction | Yes | Implemented | JWT RBAC, CEL policies, tenant isolation, `security/policies.json` |
| 8.4 | Access to source code | Yes | Implemented | GitHub CODEOWNERS, branch protection |
| 8.5 | Secure authentication | Yes | Implemented | RS256 JWT, API key auth, DPoP, `jwt_validator.tmpl` |
| 8.6 | Capacity management | Yes | Implemented | HPA, rate limiting (3 layers), circuit breakers, PDB |
| 8.7 | Protection against malware | No | N/A | Gateway doesn't execute arbitrary code; container image scanning in CI |
| 8.8 | Technical vulnerability mgmt | Yes | Implemented | Image scanning planned; `failed_jwk_key_cooldown` for key rotation |
| 8.9 | Configuration management | Yes | Implemented | GitOps, FC (Flexible Configuration), `config-audit/audit.sh`, CI validation |
| 8.10 | Information deletion | Yes | Partial | Redis TTL on cache/counters; formal retention policy planned |
| 8.11 | Data masking | Yes | Implemented | Log sanitization (prod=WARNING), PII not logged |
| 8.12 | Data leakage prevention | Yes | Partial | Security headers, CORS; DLP Lua plugin planned |
| 8.13 | Information backup | No | N/A | Gateway is stateless; config in Git (inherent backup) |
| 8.14 | Redundancy | Yes | Implemented | 2+ replicas, anti-affinity, HPA, PDB `maxUnavailable: 1` |
| 8.15 | Logging | Yes | Implemented | Structured JSON access logs, `lua/access_log.lua`, OTel traces |
| 8.16 | Monitoring activities | Yes | Implemented | Prometheus (8 alerts), OTel, Grafana, `lua/business_metrics.lua` |
| 8.17 | Clock synchronization | Yes | Implemented | K8s NTP (inherent), `os.time()` in Lua from system clock |
| 8.18 | Privileged utility programs | Yes | Implemented | No shell access, read-only filesystem, dropped ALL capabilities |
| 8.19 | Software installation | Yes | Implemented | Immutable container image, `imagePullPolicy: IfNotPresent` |
| 8.20 | Networks security | Yes | Implemented | NetworkPolicies (ingress + egress), TLS everywhere |
| 8.21 | Security of network services | Yes | Implemented | mTLS, TLS 1.2+, strong cipher suites |
| 8.22 | Segregation of networks | Yes | Implemented | K8s namespaces, NetworkPolicies per backend |
| 8.23 | Web filtering | Yes | Planned | Egress rules exist; URL-level filtering Lua plugin planned |
| 8.24 | Use of cryptography | Yes | Implemented | TLS, mTLS, JWT RS256, DPoP ES256, `mtls_backend.tmpl` |
| 8.25 | Secure development life cycle | Yes | Implemented | CI pipeline: config check + lint + docker build + audit + compliance |
| 8.26 | Application security requirements | Yes | Implemented | JSON Schema validation, `lua/json_schema_validator.lua` |
| 8.27 | Secure system architecture | Yes | Implemented | Defense-in-depth, zero trust, security headers, CEL policies |
| 8.28 | Secure coding | Yes | Implemented | Lua security patterns, input validation, output encoding |
| 8.29 | Security testing | Yes | Implemented | CI config validation; DAST planned |
| 8.30 | Outsourced development | Yes | Implemented | PR review mandatory, CODEOWNERS |
| 8.31 | Separation of environments | Yes | Implemented | `settings/{dev,staging,prod}.json`, separate K8s namespaces |
| 8.32 | Change management | Yes | Implemented | Git PR flow, CI validation, config hash annotation for rollout |
| 8.33 | Test information | Yes | Implemented | Dev settings with non-production Keycloak URLs |
| 8.34 | Audit testing protection | Yes | Implemented | Separate metrics endpoint (:8090), read-only config mount |

## Exclusion Justifications

| Control(s) | Exclusion Reason |
|------------|-----------------|
| A.7.1-7.14 (Physical) | Cloud-native deployment; physical security is CSP responsibility per ISO 27017 shared model |
| A.6.1-6.2, 6.4-6.6 (HR) | HR processes managed at organizational level, not gateway-specific |
| A.5.5-5.6 (Contacts) | External relationship management at platform level |
| A.5.10-5.11 (Use/Return) | Asset management at organizational level |
| A.5.19-5.20, 5.23 (Supplier) | Supplier management at platform level |
| A.8.1 (Endpoints) | API Gateway; no user endpoint devices |
| A.8.7 (Malware) | No arbitrary code execution in gateway |
| A.8.13 (Backup) | Stateless gateway; config in Git |

## Document Control

| Version | Date | Author | Approved By | Changes |
|---------|------|--------|-------------|---------|
| 1.0 | 2026-03-25 | Security Architect | ISMS Owner | Initial SoA — 93 controls mapped |
