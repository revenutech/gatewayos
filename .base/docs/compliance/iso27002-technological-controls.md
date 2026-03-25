---
title: "ISO 27002:2022 Technological Controls Implementation Guide — API Gateway"
iso_ref: "ISO/IEC 27002:2022 Clause 8 (Controls 8.1-8.34)"
version: "1.0"
status: Active
last_review: 2026-03-25
owner: Security Architect
classification: Internal
---

# ISO 27002 — Technological Controls (A.8) Implementation Guide

> 34 controls. Each maps ISO 27002 guidance to concrete gateway implementation with file paths.

## 8.2 Privileged Access Rights

| Attribute | Value |
|-----------|-------|
| Type | Preventive |
| CIA | C, I, A |
| Concept | Protect |
| Capability | Identity & Access Management |

**ISO 27002 Guidance:** Restrict and manage privileged access. Use authorization process, expiry, logging, separate identities, JIT elevation.

**Gateway Implementation:**
- **K8s Pod:** `runAsNonRoot: true`, `runAsUser: 1000`, `automountServiceAccountToken: false` → `k8s/manifests/deployment.yaml`
- **Container:** `readOnlyRootFilesystem: true`, `capabilities: drop ALL` → `deployment.yaml`
- **RBAC:** `ledger-admin` role required for admin endpoints → `endpoints/admin_v1.json`
- **No shell:** No exec capability in production containers
- **Audit:** All admin actions logged via `lua/audit_evidence.lua`

## 8.3 Information Access Restriction

**ISO 27002 Guidance:** Restrict access based on policy. Use dynamic access management. Control who accesses what data.

**Gateway Implementation:**
- **JWT RBAC:** Per-endpoint role validation (`roles_key: "realm_access.roles"`, `roles_key_is_nested: true`) → all `endpoints/*.json`
- **CEL policies:** Tenant isolation, Content-Type enforcement, path traversal prevention → `security/policies.json`
- **Lua policies:** SQL injection detection, XSS detection, tenant mismatch, UA blocking → `lua/security_policies.lua`
- **DLP:** Response field stripping, PII masking → `lua/dlp.lua`
- **Web filtering:** SSRF prevention, URL blocklist → `lua/web_filter.lua`

## 8.4 Access to Source Code

**Gateway Implementation:**
- **GitHub CODEOWNERS:** Security Architect required for security files
- **Branch protection:** PR review mandatory on `main`
- **Git audit:** Immutable commit history, config hash tracking

## 8.5 Secure Authentication

**ISO 27002 Guidance:** Use strong authentication based on access restrictions. Consider MFA, password policies, session management.

**Gateway Implementation:**
- **JWT RS256:** JWKS validation via Keycloak → `partials/jwt_validator.tmpl`
- **DPoP (RFC 9449):** Token binding to ephemeral client keys → `partials/security/dpop.tmpl`
- **PAR (RFC 9126):** Pushed Authorization Requests → `partials/security/par.tmpl`
- **API Key Auth:** Alternative M2M authentication → `partials/lua/api_key_auth.lua`
- **Token revocation:** Per-token (JTI), per-user, per-tenant → `partials/lua/token_revocation.lua`
- **Bloom filter:** 10M tokens, 0.0000001 FPR → `partials/bloom_filter.tmpl`
- **JWKS resilience:** Cache 1h, `failed_jwk_key_cooldown: 10s`

## 8.6 Capacity Management

**ISO 27002 Guidance:** Monitor and adjust resources. Project future needs. Implement controls against resource exhaustion.

**Gateway Implementation:**
- **HPA:** Auto-scale 2-8 pods based on CPU/memory → `k8s/manifests/hpa.yaml`
- **PDB:** `maxUnavailable: 1` for maintenance windows → `k8s/manifests/pdb.yaml`
- **Rate limiting (3 layers):**
  - L1 Nginx: 100 req/s per IP → `k8s/manifests/ingress.yaml`
  - L2 KrakenD: Global + per-tenant → `partials/rate_limiter.tmpl`
  - L3 Redis: Distributed sliding window → `partials/lua/redis_rate_limit.lua`
- **Tiered rate limits:** free/starter/pro/enterprise → `partials/lua/tiered_rate_limit.lua`
- **Circuit breakers:** Per-backend (native + custom Lua) → `partials/circuit_breaker.tmpl`, `partials/lua/circuit_breaker_custom.lua`
- **Resource limits:** CPU 250m-1000m, Memory 128Mi-512Mi → `deployment.yaml`
- **Alerts:** `KrakenDCapacityAtMaximum`, `KrakenDRateLimitSpike` → `prometheusrule.yaml`

## 8.8 Management of Technical Vulnerabilities

**Gateway Implementation:**
- **JWKS rotation:** `failed_jwk_key_cooldown: 10s` handles key rotation gracefully
- **Image pinning:** `krakend:2.7`, `envoy:v1.31-latest`
- **Planned:** Trivy image scanning, SBOM generation (CA-003)
- **CVE monitoring:** KrakenD/Envoy release tracking

## 8.9 Configuration Management

**ISO 27002 Guidance:** Establish, document, implement, monitor, review configurations including security configurations.

**Gateway Implementation:**
- **GitOps:** All config in Git, PR-based changes → `krakend/` directory
- **Flexible Configuration:** Templates + settings per env → `krakend.tmpl`, `settings/*.json`
- **CI validation:** `krakend check`, JSON lint, compliance audit → `.github/workflows/ci.yml`
- **Config audit:** Env consistency, security checks → `tools/config-audit/audit.sh`
- **Config hash:** Annotation tracks drift → `deployment.yaml` `checksum/config`
- **Hot reload:** Config reloader sidecar → `k8s/manifests/config-reloader.yaml`

## 8.10 Information Deletion

**ISO 27002 Guidance:** Delete information when no longer required.

**Gateway Implementation:**
- **Redis TTL:** All ephemeral data auto-expires (rate limits, cache, metrics)
- **Retention CronJob:** Daily enforcement, orphan key cleanup → `k8s/manifests/data-retention-cronjob.yaml`
- **Retention policy:** Documented schedules per data category → `compliance/data-retention-policy.md`
- **LGPD:** Gateway transit-only; no PII stored

## 8.11 Data Masking

**Gateway Implementation:**
- **Log level:** Prod `WARNING` (no request body/token logging) → `settings/prod.json`
- **DLP plugin:** CPF masking (`123.***.***-01`), credit card masking → `lua/dlp.lua`
- **Access logs:** Structured fields only (no raw payloads) → `lua/access_log.lua`

## 8.12 Data Leakage Prevention

**Gateway Implementation:**
- **Response DLP:** Strip sensitive fields (password, card, cpf, stack traces) → `lua/dlp.lua`
- **CORS:** Strict per-env origins (no wildcard) → `partials/cors.tmpl`, `settings/*.json`
- **Security headers:** CSP `default-src 'self'`, X-Frame-Options DENY → `partials/security_headers.tmpl`
- **Web filtering:** Block SSRF, cloud metadata endpoints → `lua/web_filter.lua`

## 8.14 Redundancy of Information Processing Facilities

**Gateway Implementation:**
- **Multi-replica:** 2+ pods always (HPA minReplicas: 2) → `hpa.yaml`
- **Anti-affinity:** Pods spread across hosts → `deployment.yaml` `podAntiAffinity`
- **PDB:** At most 1 pod unavailable → `pdb.yaml`
- **Rolling updates:** `maxSurge: 1`, `maxUnavailable: 0` → `deployment.yaml`
- **Alert:** `KrakenDReducedRedundancy` if < 2 pods → `prometheusrule-compliance.yaml`

## 8.15 Logging

**ISO 27002 Guidance:** Produce, store, protect, analyze logs of activities, exceptions, faults.

**Gateway Implementation:**
- **Access log:** Structured JSON to stdout → `lua/access_log.lua`
  - Fields: timestamp, tenant_id, user_id, endpoint, method, status, auth_method, tier, cb_state, geo_country
- **Audit evidence:** Hash-chained tamper-evident log → `lua/audit_evidence.lua`
  - Fields: seq, event_type, evidence_hash, prev_hash
- **KrakenD logging:** Logstash format, level per env → `krakend.tmpl` `telemetry/logging`
- **OTel traces:** Distributed tracing via OTLP → `partials/telemetry.tmpl`
- **Retention:** 90d access logs, 1yr audit evidence → `compliance/data-retention-policy.md`

## 8.16 Monitoring Activities

**ISO 27002 Guidance:** Monitor for anomalous behaviour. Take appropriate actions.

**Gateway Implementation:**
- **Prometheus:** 18 alert rules across 3 PrometheusRule files:
  - `prometheusrule.yaml`: Error rate, CB open, high latency, rate limit spike
  - `prometheusrule.yaml` (business): Tenant error budget, no revenue events, auth failure spike, tier exhaustion
  - `prometheusrule-compliance.yaml`: Cert expiry, config validation, access anomaly, HPA max, reduced redundancy
- **OpenTelemetry:** Traces exported via gRPC to collector → `partials/observability/opentelemetry.json`
- **Business metrics:** Per-tenant, per-tier, per-endpoint counters in Redis → `lua/business_metrics.lua`
- **ServiceMonitor:** Prometheus scrapes `:8090` every 15s → `k8s/manifests/servicemonitor.yaml`

## 8.17 Clock Synchronization

**Gateway Implementation:**
- **K8s NTP:** Kubernetes nodes synchronized via NTP (inherent)
- **Lua timestamps:** `os.time()` reads synchronized system clock
- **OTel:** Trace timestamps from synchronized system time

## 8.18 Use of Privileged Utility Programs

**Gateway Implementation:**
- **Read-only filesystem:** `readOnlyRootFilesystem: true`
- **No shell:** No `/bin/sh` or exec capability in prod
- **Capabilities dropped:** ALL capabilities removed
- **seccomp:** RuntimeDefault profile

## 8.19 Installation of Software on Operational Systems

**Gateway Implementation:**
- **Immutable image:** `Dockerfile` copies config at build time
- **No runtime install:** `readOnlyRootFilesystem: true` prevents writes
- **Image policy:** `imagePullPolicy: IfNotPresent`

## 8.20 Networks Security

**ISO 27002 Guidance:** Secure, manage, control networks to protect information.

**Gateway Implementation:**
- **Ingress policy:** Only Nginx + Prometheus → `k8s/policies/krakend-ingress.yaml`
- **Egress policy:** Explicit allow per backend + DNS + Keycloak + Redis + OTel → `k8s/policies/krakend-egress.yaml`
- **IP filtering:** Nginx allowlist/denylist + NetworkPolicy → `k8s/policies/krakend-ip-filter.yaml`
- **TLS:** Enforced on all external connections → `ingress.yaml`

## 8.21 Security of Network Services

**Gateway Implementation:**
- **mTLS:** ECDSA P-256 client certs for backends → `partials/mtls_backend.tmpl`
- **TLS 1.2+:** Minimum version enforced, TLS 1.3 supported
- **Cipher suites:** AES-256-GCM, AES-128-GCM (ECDHE key exchange)
- **Auto-rotation:** cert-manager 1yr duration, 30d renewal → `k8s/manifests/mtls-certificates.yaml`

## 8.22 Segregation of Networks

**Gateway Implementation:**
- **K8s namespaces:** Backends in separate namespaces
- **NetworkPolicies:** Per-backend allow rules (no default access)
- **WS segregation:** Separate ingress for WebSocket traffic → `k8s/manifests/ws-proxy-ingress.yaml`

## 8.23 Web Filtering

**Gateway Implementation:**
- **Egress rules:** NetworkPolicy restricts outbound to known backends → `krakend-egress.yaml`
- **SSRF prevention:** Block cloud metadata, dangerous protocols → `lua/web_filter.lua`
- **Domain blocklist:** Extensible list in Lua plugin

## 8.24 Use of Cryptography

**ISO 27002 Guidance:** Define rules for effective cryptography. Manage keys.

**Gateway Implementation:**
- **TLS:** All external traffic encrypted (Nginx `ssl-redirect: true`)
- **mTLS:** Backend communication (`mtls_backend.tmpl`)
- **JWT RS256:** Keycloak JWKS key management
- **DPoP ES256:** Ephemeral proof-of-possession keys
- **Key management:** cert-manager auto-rotation, K8s secret storage
- **Cipher policy:** Strong suites only (AES-GCM, ECDHE)
- **Alert:** `KrakenDCertExpiringIn30Days/7Days` → `prometheusrule-compliance.yaml`

## 8.25 Secure Development Life Cycle

**Gateway Implementation:**
- **CI pipeline:** Config check → lint → audit → docker build → compliance check
- **PR review:** CODEOWNERS mandatory review
- **Compliance CI:** ISO compliance validation on every PR → `.github/workflows/compliance.yml`
- **OpenAPI generator:** API spec generated in CI → `tools/openapi-generator/`

## 8.26 Application Security Requirements

**Gateway Implementation:**
- **JSON Schema validation:** Request body validation for postings, settlements, reconciliation → `lua/json_schema_validator.lua`
- **CEL validation:** Input validation rules (tenant, content-type, path traversal, query size) → `security/policies.json`
- **Content-Type enforcement:** POST/PUT/PATCH must send `application/json`

## 8.27 Secure System Architecture and Engineering Principles

**Gateway Implementation:**
- **Defense-in-depth:** 4 layers (Nginx → KrakenD → NetworkPolicy → Backend)
- **Zero trust:** Every request authenticated regardless of origin
- **Least privilege:** Minimum RBAC roles, dropped capabilities, non-root
- **Fail secure:** Token failure → 401, Redis down → degraded limits, CB open → 503
- **Security headers:** HSTS, CSP, X-Frame-Options, nosniff, referrer-policy → `partials/security_headers.tmpl`

## 8.28 Secure Coding

**Gateway Implementation:**
- **Lua patterns:** Input validation, output encoding, error handling
- **SQL injection prevention:** `lua/security_policies.lua` pattern detection
- **XSS prevention:** Header sanitization, CSP `default-src 'self'`
- **Path traversal:** CEL validation blocks `..`, `//`, encoded variants

## 8.29 Security Testing in Development and Acceptance

**Gateway Implementation:**
- **Config validation:** `krakend check` in CI
- **JSON lint:** All settings files validated
- **Compliance audit:** `audit.sh --strict` in CI
- **Planned:** DAST scanning against staging endpoints

## 8.31 Separation of Development, Test and Production Environments

**Gateway Implementation:**
- **Per-env settings:** `settings/dev.json`, `settings/staging.json`, `settings/prod.json`
- **Env differences:** log level (DEBUG/INFO/WARNING), CORS origins, error exposure, rate limits
- **K8s namespaces:** Separate namespaces per environment
- **Test API keys:** Only in dev settings, empty registry in staging/prod

## 8.32 Change Management

**Gateway Implementation:**
- **Git PR flow:** All changes via pull requests
- **CI validation:** Automated before merge
- **Config hash:** Deployment annotation triggers rolling update
- **Rollback:** `kubectl rollout undo` or `git revert`
- **Procedure:** `operations/change-management.md`

## Controls Not Applicable to Gateway

| Control | Reason |
|---------|--------|
| 8.1 User endpoint devices | API-only, no user endpoints |
| 8.7 Protection against malware | No arbitrary code execution |
| 8.13 Information backup | Stateless; config in Git |
| 8.30 Outsourced development | PR review covers (impl as 8.30) |
| 8.33 Test information | Dev settings cover (impl as 8.33) |
| 8.34 Audit testing protection | Metrics endpoint cluster-internal (impl as 8.34) |

---

## ISO 27002:2022 Attribute Table — All Applicable Technological Controls

| # | Control | Type | CIA | Cybersecurity Concept | Operational Capability | Security Domain |
|---|---------|------|-----|----------------------|----------------------|----------------|
| 8.2 | Privileged access rights | Preventive | C,I,A | Protect | IAM | Protection |
| 8.3 | Information access restriction | Preventive | C,I,A | Protect | IAM | Protection |
| 8.4 | Access to source code | Preventive | C,I,A | Protect | IAM, App security, Secure config | Protection |
| 8.5 | Secure authentication | Preventive | C,I,A | Protect | IAM | Protection |
| 8.6 | Capacity management | Preventive, Detective | I,A | Protect, Detect | Continuity, Asset mgmt | Protection, Resilience |
| 8.8 | Technical vulnerability mgmt | Preventive | C,I,A | Identify, Protect | Threat & vulnerability mgmt | Protection |
| 8.9 | Configuration management | Preventive | C,I,A | Protect | Secure configuration | Protection |
| 8.10 | Information deletion | Preventive | C | Protect | Information protection, Legal | Protection |
| 8.11 | Data masking | Preventive | C | Protect | Information protection | Protection |
| 8.12 | Data leakage prevention | Preventive, Detective | C | Protect, Detect | Information protection | Protection, Defence |
| 8.14 | Redundancy | Preventive | A | Protect | Continuity, Asset mgmt | Resilience |
| 8.15 | Logging | Detective | C,I,A | Detect | Event management | Defence |
| 8.16 | Monitoring activities | Detective, Corrective | C,I,A | Detect, Respond | Event management | Defence |
| 8.17 | Clock synchronization | Detective | I | Detect | Event management | Protection, Defence |
| 8.18 | Privileged utility programs | Preventive | C,I,A | Protect | System & network security | Protection |
| 8.19 | Software installation | Preventive | C,I,A | Protect | Secure configuration, App security | Protection |
| 8.20 | Networks security | Preventive, Detective | C,I,A | Protect, Detect | System & network security | Protection |
| 8.21 | Security of network services | Preventive | C,I,A | Protect | System & network security | Protection |
| 8.22 | Segregation of networks | Preventive | C,I,A | Protect | System & network security | Protection |
| 8.23 | Web filtering | Preventive | C,I,A | Protect | System & network security | Protection |
| 8.24 | Use of cryptography | Preventive | C,I | Protect | Secure configuration | Protection |
| 8.25 | Secure development life cycle | Preventive | C,I,A | Protect | App security | Protection |
| 8.26 | Application security requirements | Preventive | C,I,A | Protect | App security | Protection |
| 8.27 | Secure system architecture | Preventive | C,I,A | Protect | App security, Secure config | Protection |
| 8.28 | Secure coding | Preventive | C,I,A | Protect | App security | Protection |
| 8.29 | Security testing | Preventive, Detective | C,I,A | Identify, Protect | App security | Protection |
| 8.30 | Outsourced development | Preventive | C,I,A | Protect | App security, Supplier security | Protection |
| 8.31 | Separation of environments | Preventive | C,I,A | Protect | App security, Secure config | Protection |
| 8.32 | Change management | Preventive | C,I,A | Protect | App security, Secure config | Protection |
| 8.33 | Test information | Preventive | C | Protect | Information protection | Protection |
| 8.34 | Audit testing protection | Preventive | C,I,A | Protect | System & network security | Protection |

> **Cross-references:** [Organizational Controls](iso27002-organizational-controls.md) | [Controls Matrix](controls-matrix.md) | [SoA](../risk/statement-of-applicability.md)
