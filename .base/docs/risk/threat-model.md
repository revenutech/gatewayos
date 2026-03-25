---
title: "STRIDE Threat Model — API Gateway"
iso_ref: "ISO/IEC 27005:2022 Cl. 8.2, ISO/IEC 27001:2022 Cl. 6.1.2"
version: "1.0"
status: Active
last_review: 2026-03-25
next_review: 2026-09-25
owner: Security Architect
classification: Confidential
---

# STRIDE Threat Model — API Gateway

## 1. System Context

```
                    ┌──────────────────────────────────────────────────┐
                    │               Trust Boundary: Internet           │
  Clients ─────────┤                                                  │
  (browsers,       │    ┌──────────┐    ┌──────────┐    ┌──────────┐ │
   mobile,         ├───→│  Nginx   │───→│ KrakenD  │───→│ Backends │ │
   M2M)            │    │ Ingress  │    │ Gateway  │    │ (7 svc)  │ │
                    │    └──────────┘    └────┬─────┘    └──────────┘ │
                    │         TB1        TB2  │  TB3          TB4     │
                    │                    ┌────┴─────┐                  │
                    │                    │  Redis   │                  │
                    │                    │ Keycloak │                  │
                    │                    │  OTel    │                  │
                    │                    └──────────┘                  │
                    │               Trust Boundary: Cluster            │
                    └──────────────────────────────────────────────────┘
```

**Trust Boundaries:**
- **TB1:** Internet → Nginx Ingress (TLS termination)
- **TB2:** Nginx → KrakenD (internal HTTP)
- **TB3:** KrakenD → External services (Keycloak, Redis)
- **TB4:** KrakenD → Backend services (mTLS)

## 2. STRIDE Analysis

### S — Spoofing

| ID | Threat | Component | Mitigations | Risk Ref | Controls |
|----|--------|-----------|-------------|----------|----------|
| S1 | Attacker spoofs JWT token | KrakenD JWT validator | RS256 signature verification, JWKS rotation, `failed_jwk_key_cooldown` | R01 | A.8.5 |
| S2 | Stolen API key reuse | KrakenD API key plugin | Key disable mechanism, per-tenant scoping, tier-based rate limiting | R03 | A.8.5 |
| S3 | Forged tenant identity | X-Tenant-ID header | JWT claim propagation (not client-supplied), CEL mismatch detection | R08 | A.8.3, A.5.15 |
| S4 | IP address spoofing | Nginx Ingress | X-Forwarded-For validation, `proxy_set_header X-Real-IP $remote_addr` | R02 | A.8.20 |
| S5 | mTLS cert impersonation | Envoy/Backend | cert-manager rotation, ECDSA P-256, CA validation | R06 | A.8.24 |

### T — Tampering

| ID | Threat | Component | Mitigations | Risk Ref | Controls |
|----|--------|-----------|-------------|----------|----------|
| T1 | Request body manipulation | KrakenD endpoint | JSON Schema validation, Content-Type enforcement, body size limits | R01 | A.8.26 |
| T2 | Configuration tampering | Git repository | CODEOWNERS, PR review, CI validation, config hash annotation | R05 | A.8.9, A.8.32 |
| T3 | Log tampering | Audit logs | Append-only stdout, hash chain planned, read-only filesystem | R13 | A.5.28, A.8.15 |
| T4 | Redis data manipulation | Redis | Network policy restriction, no public access, authentication planned | R16 | A.8.20 |
| T5 | Path traversal injection | URL routing | CEL path validation (no `..`, `//`, `%2e`), query string size limit | R01 | A.8.3 |

### R — Repudiation

| ID | Threat | Component | Mitigations | Risk Ref | Controls |
|----|--------|-----------|-------------|----------|----------|
| R-1 | Deny malicious API call | Access log | Structured JSON access log: tenant, user, endpoint, status, timestamp, correlation_id | R13 | A.8.15 |
| R-2 | Deny config change | Git + CI | Git commit history, signed commits planned, CI audit trail | R05 | A.8.32, A.5.28 |
| R-3 | Deny token revocation action | Redis + logs | Redis SET with timestamp, admin action logged | R01 | A.5.28 |

### I — Information Disclosure

| ID | Threat | Component | Mitigations | Risk Ref | Controls |
|----|--------|-----------|-------------|----------|----------|
| I1 | PII leak in logs | Access logger | Prod log_level=WARNING, token/PII not logged, DLP planned | R10 | A.8.11, A.5.34 |
| I2 | Error message disclosure | KrakenD response | `return_error_msg: false` in prod, generic error responses | R10 | A.8.27 |
| I3 | TLS downgrade exposes traffic | Nginx Ingress | `ssl-redirect: true`, `force-ssl-redirect: true`, TLS 1.2+ only | R14 | A.8.24 |
| I4 | CORS misconfiguration | KrakenD CORS | Strict per-env origins (no wildcard), CI audit validates | R08 | A.8.20 |
| I5 | Response header leakage | Security headers | HSTS, X-Frame-Options DENY, CSP, nosniff, referrer-policy | R10 | A.8.27 |

### D — Denial of Service

| ID | Threat | Component | Mitigations | Risk Ref | Controls |
|----|--------|-----------|-------------|----------|----------|
| D1 | Volumetric DDoS | Nginx + KrakenD | 3-layer rate limiting, HPA (2-8 pods), GeoIP blocking | R02 | A.8.6 |
| D2 | Application-layer DDoS | KrakenD endpoints | Per-tenant rate limits, tiered limits, suspicious UA blocking | R02 | A.8.6 |
| D3 | Backend cascade failure | Circuit breakers | Per-backend CB (CE native + custom Lua), PDB, graceful 503 | R04 | A.8.6, A.5.29 |
| D4 | Redis exhaustion | Redis connection | Fail-open in all Lua scripts, local fallback rate limits | R16 | A.8.14 |
| D5 | Bloom filter overflow | Token revocation | 10M capacity, TTL-based cleanup, Redis backup revocation | R15 | A.5.17 |

### E — Elevation of Privilege

| ID | Threat | Component | Mitigations | Risk Ref | Controls |
|----|--------|-----------|-------------|----------|----------|
| E1 | Role escalation via JWT manipulation | JWT validator | RS256 signature — can't modify claims without private key | R01 | A.8.5 |
| E2 | Container breakout | K8s pod | Non-root, read-only FS, dropped ALL capabilities, seccomp RuntimeDefault | R09 | A.8.2, A.8.18 |
| E3 | Admin endpoint access | RBAC | `ledger-admin` role required, separate endpoint file | R08 | A.8.2, A.8.3 |
| E4 | Service account token theft | K8s | `automountServiceAccountToken: false` | R09 | A.8.2 |

## 3. Attack Surface Summary

| Surface | Exposure | Controls Count | Risk Level |
|---------|----------|:--------------:|:----------:|
| Public API (:8080) | Internet | 12 | Medium |
| Metrics (:8090) | Cluster-internal | 3 | Low |
| WebSocket (/ws/*) | Internet (bypass GW) | 4 | Medium |
| Envoy transcoder (:8085) | Pod-local / Docker | 3 | Low |
| Redis (:6379) | Cluster-internal | 2 | Medium |
| Config (Git) | Authenticated | 4 | Low |

## 4. Document Control

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | 2026-03-25 | Security Architect | Initial STRIDE analysis — 26 threats across 6 categories |
