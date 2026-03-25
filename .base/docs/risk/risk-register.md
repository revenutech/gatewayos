---
title: "Risk Register & Treatment Plan — API Gateway"
iso_ref: "ISO/IEC 27005:2022 Cl. 8-10, ISO/IEC 27001:2022 Cl. 6.1.2-6.1.3"
version: "1.0"
status: Active
last_review: 2026-03-25
next_review: 2026-06-25
owner: Security Architect
classification: Confidential
---

# Risk Register & Treatment Plan — API Gateway

## Risk Register

| ID | Risk | Threat | Vulnerability | L | I | Score | Level | Treatment | Owner | Controls | Status |
|----|------|--------|---------------|:-:|:-:|:-----:|-------|-----------|-------|----------|--------|
| R01 | **JWT token theft/replay** | Attacker intercepts or steals JWT token | Token in transit, XSS in client app, insufficient token binding | 4 | 4 | **16** | Critical | Mitigate | Sec Architect | A.8.5, A.8.24, A.5.17 | Treated |
| R02 | **DDoS / volumetric attack** | External attacker floods gateway | Public-facing endpoint, insufficient rate limiting | 4 | 4 | **16** | Critical | Mitigate | DevSecOps | A.8.6, A.8.20 | Treated |
| R03 | **Credential stuffing** | Automated brute-force auth attempts | Public auth endpoint, weak detection | 4 | 3 | **12** | High | Mitigate | Sec Architect | A.8.5, A.8.16 | Treated |
| R04 | **Backend cascade failure** | Single backend failure cascades to all | Circuit breaker misconfiguration, shared resources | 3 | 4 | **12** | High | Mitigate | DevSecOps | A.8.6, A.5.29 | Treated |
| R05 | **Config tampering** | Unauthorized KrakenD config change | Insufficient access control on config repo | 2 | 5 | **10** | High | Mitigate | DevSecOps | A.8.9, A.8.32, A.8.4 | Treated |
| R06 | **TLS certificate compromise** | Private key exposed or stolen | Key storage vulnerability, rotation failure | 2 | 5 | **10** | High | Mitigate | DevSecOps | A.8.24, A.5.14 | Treated |
| R07 | **JWKS endpoint unavailability** | Keycloak JWKS endpoint down | Single point of failure, no cache fallback | 3 | 3 | **9** | Medium | Mitigate | Sec Architect | A.8.5, A.8.14 | Treated |
| R08 | **Cross-tenant data leakage** | Tenant A accesses Tenant B data | Header manipulation, RBAC bypass | 2 | 5 | **10** | High | Mitigate | Sec Architect | A.8.3, A.5.15 | Treated |
| R09 | **Supply chain attack** | Compromised KrakenD/Envoy image | Third-party dependency vulnerability | 2 | 5 | **10** | High | Mitigate | DevSecOps | A.5.21, A.8.8, A.8.19 | Partial |
| R10 | **Sensitive data in logs** | PII/tokens leaked in access logs | Insufficient log sanitization | 3 | 3 | **9** | Medium | Mitigate | Sec Architect | A.8.15, A.8.11, A.5.34 | Treated |
| R11 | **Rate limit bypass** | Attacker evades rate limiting | IP rotation, header manipulation, distributed attack | 3 | 2 | **6** | Medium | Mitigate | Sec Architect | A.8.6, A.8.3 | Treated |
| R12 | **Zero-day in KrakenD** | Undisclosed vulnerability exploited | No patch available, public-facing | 2 | 4 | **8** | Medium | Accept + Monitor | DevSecOps | A.8.8, A.5.7 | Monitored |
| R13 | **Insider threat** | Malicious team member modifies config | Privileged access, insufficient audit | 2 | 4 | **8** | Medium | Mitigate | ISMS Owner | A.8.4, A.8.15, A.5.3 | Treated |
| R14 | **TLS downgrade attack** | MITM forces weaker cipher | Cipher suite misconfiguration | 1 | 4 | **4** | Low | Mitigate | Sec Architect | A.8.24, A.8.20 | Treated |
| R15 | **Bloom filter false positive** | Legitimate tokens wrongly rejected | High FPR, capacity exceeded | 2 | 2 | **4** | Low | Accept | Sec Architect | A.5.17 | Accepted |
| R16 | **Redis SPOF** | Redis failure breaks rate limiting + revocation | Single Redis instance, no failover | 3 | 3 | **9** | Medium | Mitigate | DevSecOps | A.8.14, A.8.6 | Partial |
| R17 | **Geo-blocking evasion** | Attacker uses VPN to bypass geo restrictions | VPN/proxy usage | 3 | 2 | **6** | Medium | Accept + Monitor | Sec Architect | A.8.3 | Accepted |

## Treatment Plan

| Risk ID | Treatment Actions | Target Date | Evidence |
|---------|-------------------|-------------|----------|
| R01 | (a) DPoP token binding implemented; (b) Token revocation via Redis (per-token, per-user, per-tenant); (c) Short-lived tokens (1h TTL); (d) Bloom filter with 0.0000001 FPR | Done | `partials/security/dpop.tmpl`, `lua/token_revocation.lua`, `partials/bloom_filter.tmpl` |
| R02 | (a) 3-layer rate limiting (Nginx IP + KrakenD global/tenant + Redis tiered); (b) IP filtering at Nginx; (c) GeoIP blocking; (d) HPA auto-scaling | Done | `ingress.yaml`, `lua/redis_rate_limit.lua`, `lua/tiered_rate_limit.lua`, `hpa.yaml` |
| R03 | (a) Auth failure monitoring alert (>50/s); (b) Suspicious UA blocking; (c) Rate limit on auth endpoints | Done | `prometheusrule.yaml`, `lua/security_policies.lua`, endpoint rate limits |
| R04 | (a) Per-backend circuit breakers (CE native); (b) Custom Lua CB (only 5xx trips); (c) PDB for zero-downtime; (d) Graceful degradation (503 + Retry-After) | Done | `partials/circuit_breaker.tmpl`, `lua/circuit_breaker_custom.lua`, `pdb.yaml` |
| R05 | (a) CODEOWNERS requiring security review; (b) CI config validation; (c) Config hash annotation for drift detection; (d) Git audit trail | Done | `.github/workflows/ci.yml`, `tools/config-audit/audit.sh` |
| R06 | (a) cert-manager auto-rotation (30-day renewal); (b) ECDSA P-256 keys; (c) TLS 1.2+ with strong ciphers; (d) K8s secret mount (not env var) | Done | `k8s/manifests/mtls-certificates.yaml`, `partials/mtls_backend.tmpl` |
| R07 | (a) JWKS cache 1h; (b) `failed_jwk_key_cooldown: 10s`; (c) Keycloak HA (external) | Done | `partials/jwt_validator.tmpl` |
| R08 | (a) CEL tenant_id validation; (b) JWT tenant_id → header mismatch check; (c) Tenant-scoped Redis keys; (d) Network policy isolation | Done | `security/policies.json`, `lua/security_policies.lua` |
| R09 | (a) Pin image versions in CI; (b) Trivy scanning planned; (c) SBOM generation planned | 2026-Q2 | CI pipeline (partial) |
| R10 | (a) Structured access logs without raw tokens; (b) DLP Lua plugin planned; (c) Log-level filtering (prod=WARNING) | Partial | `lua/access_log.lua`, `settings/prod.json` |
| R13 | (a) PR review required; (b) Segregation of duties (RACI); (c) Git signed commits planned | Partial | `isms/roles-responsibilities.md` |
| R16 | (a) Redis Sentinel/Cluster planned; (b) Fail-open design in all Lua scripts | 2026-Q2 | `lua/redis_rate_limit.lua` (fail-open) |

## Residual Risk Summary

| Level | Count | Risks |
|-------|-------|-------|
| Critical | 0 | — (all treated below threshold) |
| High | 2 | R09 (supply chain — partial), R08 (residual after controls) |
| Medium | 4 | R10, R12, R16, R17 |
| Low | 2 | R14, R15 |
| Accepted | 3 | R12 (zero-day), R15 (bloom filter FP), R17 (geo evasion) |

## Document Control

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | 2026-03-25 | Security Architect | Initial risk register with 17 risks |
