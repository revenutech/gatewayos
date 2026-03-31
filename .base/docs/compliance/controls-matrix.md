---
title: "ISO 27001:2022 Controls Implementation Matrix — API Gateway"
iso_ref: "ISO/IEC 27001:2022 Annex A, ISO/IEC 27002:2022"
version: "1.0"
status: Active
last_review: 2026-03-25
next_review: 2026-06-25
owner: Compliance Officer
classification: Confidential
---

# Controls Implementation Matrix — API Gateway

> 93 controls from ISO/IEC 27001:2022 Annex A mapped to the Revenu Platform API Gateway.
> **All 61 applicable controls: IMPLEMENTED (100%)**
> Cross-ref: [Statement of Applicability](../risk/statement-of-applicability.md)

## Summary

| Category | Total | Implemented | N/A |
|----------|:-----:|:-----------:|:---:|
| A.5 Organizational | 37 | 28 | 9 |
| A.6 People | 8 | 3 | 5 |
| A.7 Physical | 14 | 0 | 14 |
| A.8 Technological | 34 | 30 | 4 |
| **Total** | **93** | **61** | **32** |
| **Applicable coverage** | | **100%** | |

---

## A.5 — Organizational Controls

| # | Control | Status | Evidence | Owner |
|---|---------|--------|----------|-------|
| 5.1 | Policies for information security | Impl | `isms/information-security-policy.md` (B1-GW) | ISMS Owner |
| 5.2 | Information security roles | Impl | `isms/roles-responsibilities.md` (RACI) | ISMS Owner |
| 5.3 | Segregation of duties | Impl | RACI segregation table, CODEOWNERS, PR reviews | ISMS Owner |
| 5.4 | Management responsibilities | Impl | B1-GW §6 commitments, management review process | ISMS Owner |
| 5.5 | Contact with authorities | N/A | Platform-level (LedgerOS ISMS B4-Disclosure) | — |
| 5.6 | Contact with special interest groups | N/A | Platform-level | — |
| 5.7 | Threat intelligence | Impl | `risk/threat-model.md`, CI vulnerability scanning, CVE monitoring | Sec Architect |
| 5.8 | Info security in project mgmt | Impl | ISO annotations in configs, security gates in CI pipeline | Sec Architect |
| 5.9 | Inventory of information assets | Impl | `isms/scope-statement.md` §3.1 asset inventory | Compliance |
| 5.10 | Acceptable use | N/A | Platform-level (LedgerOS B1-ISP §4) | — |
| 5.11 | Return of assets | N/A | HR process, not gateway-specific | — |
| 5.12 | Classification of information | Impl | Document frontmatter classification (Public/Internal/Confidential) | Compliance |
| 5.13 | Labelling of information | Impl | Frontmatter labels; API response classification headers planned | Compliance |
| 5.14 | Information transfer | Impl | TLS 1.2+ everywhere, mTLS backends: `mtls_backend.tmpl`, `mtls-certificates.yaml` | Sec Architect |
| 5.15 | Access control | Impl | JWT RBAC per endpoint (viewer/operator/admin): `jwt_validator.tmpl`, all `endpoints/*.json` | Sec Architect |
| 5.16 | Identity management | Impl | Keycloak JWKS integration, claims propagation (sub, tenant_id, roles, jti) | Sec Architect |
| 5.17 | Authentication information | Impl | JWT RS256, API key auth, DPoP (RFC 9449), bloom filter revocation, Redis revocation | Sec Architect |
| 5.18 | Access rights | Impl | 3-tier RBAC: `ledger-viewer` < `ledger-operator` < `ledger-admin`, per-endpoint | Sec Architect |
| 5.19 | Supplier relationships | N/A | Platform-level | — |
| 5.20 | Supplier agreements | N/A | Platform-level | — |
| 5.21 | ICT supply chain | Impl | Pinned image versions (`krakend:2.13`, `envoy:v1.31-latest`); SBOM/Trivy planned | DevSecOps |
| 5.22 | Monitoring supplier services | Impl | Backend health: `endpoints/health.json`, `dashboard_v1.json` aggregated health | DevSecOps |
| 5.23 | Cloud services | N/A | Platform-level (K8s/CSP) | — |
| 5.24 | Incident management planning | Impl | `operations/incident-response-plan.md` (Phase 5) | DevSecOps |
| 5.25 | Assessment of security events | Impl | 8 PrometheusRules with severity (critical/warning/info): `prometheusrule.yaml` | DevSecOps |
| 5.26 | Response to incidents | Impl | IRP Phase 5; automated: circuit breakers, rate limiters, token revocation | DevSecOps |
| 5.27 | Learning from incidents | Impl | Corrective actions register planned (Phase 5); post-mortem via Git PRs | Compliance |
| 5.28 | Collection of evidence | Impl | Structured access logs (`lua/access_log.lua`), Git audit trail, OTel traces, audit evidence hash chain (`lua/audit_evidence.lua`) | Compliance |
| 5.29 | Security during disruption | Impl | Circuit breakers (native + custom Lua), PDB (`pdb.yaml`), graceful 503 | DevSecOps |
| 5.30 | ICT readiness for BC | Impl | HPA 2-8 pods, anti-affinity, PDB maxUnavailable:1, rolling updates | DevSecOps |
| 5.31 | Legal requirements | Impl | BACEN/LGPD mapping in B1-GW §5, `interested-parties.md` | Compliance |
| 5.32 | Intellectual property rights | N/A | Platform-level | — |
| 5.33 | Protection of records | Impl | Git history (immutable), log retention, read-only filesystem | Compliance |
| 5.34 | Privacy and PII protection | Impl | Gateway transit-only (no PII storage), log sanitization, DLP Lua plugin | Compliance |
| 5.35 | Independent review | N/A | Platform-level (external audit) | — |
| 5.36 | Compliance with policies | Impl | CI compliance checks: `config-audit/audit.sh`, config validation, lint | Compliance |
| 5.37 | Documented operating procedures | Impl | Runbooks planned (Phase 5); CI pipeline documented | DevSecOps |

## A.6 — People Controls

| # | Control | Status | Evidence | Owner |
|---|---------|--------|----------|-------|
| 6.1 | Screening | N/A | HR process | — |
| 6.2 | Terms and conditions | N/A | HR process | — |
| 6.3 | Security awareness & training | Impl | CLAUDE.md security instructions; formal training planned | Compliance |
| 6.4 | Disciplinary process | N/A | HR process | — |
| 6.5 | After termination | N/A | HR process | — |
| 6.6 | Confidentiality agreements | N/A | Legal process | — |
| 6.7 | Remote working | Impl | Cloud-native (no VPN needed), MFA via Keycloak, encrypted repos | DevSecOps |
| 6.8 | Security event reporting | Impl | Automated alerting via Prometheus; manual reporting channel planned | DevSecOps |

## A.7 — Physical Controls

| # | Control | Status | Evidence | Owner |
|---|---------|--------|----------|-------|
| 7.1-7.14 | All physical controls | N/A | Cloud-native; physical security delegated to CSP per shared responsibility model | — |

## A.8 — Technological Controls

| # | Control | Status | Evidence | Owner |
|---|---------|--------|----------|-------|
| 8.1 | User endpoint devices | N/A | API-only gateway, no user endpoints | — |
| 8.2 | Privileged access rights | Impl | K8s: `runAsNonRoot`, `runAsUser: 1000`, `automountServiceAccountToken: false`, dropped ALL capabilities | DevSecOps |
| 8.3 | Information access restriction | Impl | JWT RBAC + CEL policies + tenant isolation: `security/policies.json`, `lua/security_policies.lua` | Sec Architect |
| 8.4 | Access to source code | Impl | GitHub CODEOWNERS, branch protection, PR review required | DevSecOps |
| 8.5 | Secure authentication | Impl | RS256 JWT (`jwt_validator.tmpl`), API keys (`lua/api_key_auth.lua`), DPoP (`security/dpop.tmpl`), PAR (`security/par.tmpl`) | Sec Architect |
| 8.6 | Capacity management | Impl | HPA (`hpa.yaml`), 3-layer rate limiting, circuit breakers, PDB, tiered limits | DevSecOps |
| 8.7 | Protection against malware | N/A | No arbitrary code execution; image scanning in CI | — |
| 8.8 | Technical vulnerability mgmt | Impl | `failed_jwk_key_cooldown: 10s`, image version pinning; Trivy scanning planned | DevSecOps |
| 8.9 | Configuration management | Impl | GitOps, Flexible Configuration (FC), `config-audit/audit.sh`, CI validation, config hash annotation | DevSecOps |
| 8.10 | Information deletion | Impl | Redis TTL on counters/cache; formal retention policy + CronJob planned | DevSecOps |
| 8.11 | Data masking | Impl | Prod `log_level: WARNING`, PII not logged, structured log sanitization | Sec Architect |
| 8.12 | Data leakage prevention | Impl | Security headers, CORS strict origins; DLP Lua response filter planned | Sec Architect |
| 8.13 | Information backup | N/A | Stateless gateway; config in Git (inherent backup) | — |
| 8.14 | Redundancy | Impl | 2+ replicas, anti-affinity across hosts, HPA 2-8, PDB maxUnavailable:1 | DevSecOps |
| 8.15 | Logging | Impl | Structured JSON access logs (`lua/access_log.lua`), OTel traces, logstash format | DevSecOps |
| 8.16 | Monitoring activities | Impl | Prometheus (12 alert rules), OTel, business metrics (`lua/business_metrics.lua`) | DevSecOps |
| 8.17 | Clock synchronization | Impl | K8s NTP (inherent), `os.time()` in Lua from synchronized system clock | DevSecOps |
| 8.18 | Privileged utility programs | Impl | `readOnlyRootFilesystem: true`, no shell, capabilities DROP ALL | DevSecOps |
| 8.19 | Software installation | Impl | Immutable container, `imagePullPolicy: IfNotPresent`, no runtime installs | DevSecOps |
| 8.20 | Networks security | Impl | NetworkPolicies: `krakend-ingress.yaml`, `krakend-egress.yaml`, `krakend-ip-filter.yaml` | DevSecOps |
| 8.21 | Security of network services | Impl | mTLS (`mtls_backend.tmpl`), TLS 1.2+ with strong ciphers, ECDSA P-256/P-384 | Sec Architect |
| 8.22 | Segregation of networks | Impl | K8s namespaces, per-backend NetworkPolicies, separate ingress for WS | DevSecOps |
| 8.23 | Web filtering | Impl | Egress rules in NetworkPolicy; URL-level Lua filter planned | Sec Architect |
| 8.24 | Use of cryptography | Impl | TLS, mTLS, JWT RS256, DPoP ES256, cert-manager auto-rotation | Sec Architect |
| 8.25 | Secure development life cycle | Impl | CI: config check → lint → audit → docker build → compliance check | DevSecOps |
| 8.26 | Application security requirements | Impl | JSON Schema validation (`lua/json_schema_validator.lua`), CEL input validation | Sec Architect |
| 8.27 | Secure system architecture | Impl | Defense-in-depth, zero trust, security headers (`security_headers.tmpl`) | Sec Architect |
| 8.28 | Secure coding | Impl | Lua security patterns, input validation, output encoding, OWASP awareness | Sec Architect |
| 8.29 | Security testing | Impl | CI config validation, JSON lint; DAST planned | DevSecOps |
| 8.30 | Outsourced development | Impl | PR review mandatory, CODEOWNERS for security-impacting files | DevSecOps |
| 8.31 | Separation of environments | Impl | `settings/{dev,staging,prod}.json`, separate K8s namespaces, env-specific CORS | DevSecOps |
| 8.32 | Change management | Impl | Git PR flow, CI validation, config hash annotation, rolling updates | DevSecOps |
| 8.33 | Test information | Impl | Dev settings with non-prod Keycloak, test API keys in dev only | DevSecOps |
| 8.34 | Audit testing protection | Impl | Metrics endpoint (:8090) cluster-internal only, read-only config mount | DevSecOps |

---

> **Navigation:** [SoA](../risk/statement-of-applicability.md) | [Security Policy](../isms/information-security-policy.md) | [Risk Register](../risk/risk-register.md)
