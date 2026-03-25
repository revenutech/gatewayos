---
title: ISMS Scope Statement — Revenu Platform API Gateway
iso_ref: ISO/IEC 27001:2022 Clause 4.3, ISO/IEC 27003:2017 Clause 4
version: "1.0"
status: Approved
last_review: 2026-03-25
next_review: 2026-09-25
owner: ISMS Owner
classification: Internal
---

# ISMS Scope Statement — API Gateway

## 1. Purpose

This document defines the boundaries and applicability of the Information Security Management System (ISMS) for the Revenu Platform API Gateway, in accordance with ISO/IEC 27001:2022 Clause 4.3.

## 2. Organizational Context (Cl. 4.1)

### 2.1 External Issues

| Issue | Relevance |
|-------|-----------|
| BACEN Resolution 4.893/2021 | Mandatory cybersecurity requirements for financial institutions |
| CMN Resolution 4.658/2018 | Cloud computing policy for regulated institutions |
| LGPD (Lei 13.709/2018) | Personal data protection requirements |
| ANPD regulations | Privacy authority enforcement |
| PIX/SPI requirements | Real-time payment system security standards |
| ISO 20022 messaging | Financial messaging standard compliance |
| Competitive fintech landscape | Market expectation for ISO 27001 certification |

### 2.2 Internal Issues

| Issue | Relevance |
|-------|-----------|
| KrakenD 2.7 Community Edition | API Gateway technology stack |
| Microservices architecture | 7 backend modules (LedgerOS, Paymentos, AtmOS, Identos, OnboardOS, AccountOS, FinanceOS) |
| Kubernetes deployment | Container orchestration on cloud infrastructure |
| Keycloak integration | Centralized identity and access management |
| Team competency | DevSecOps practices, Go/K8s expertise |
| Allenty governance framework | Integrated management system methodology |

## 3. ISMS Scope

### 3.1 In Scope

The ISMS for the API Gateway covers:

**Information Assets:**
- KrakenD gateway configuration (templates, partials, settings, endpoints)
- JWT tokens and authentication credentials in transit
- API keys and their metadata
- Rate limiting and circuit breaker state data
- Access logs and audit trails
- TLS/mTLS certificates and private keys
- Prometheus metrics and OpenTelemetry traces

**Technology Components:**
- KrakenD v2.7 API Gateway (all configuration and runtime)
- Envoy gRPC-REST transcoder sidecar
- Redis (rate limiting, token revocation, response cache, business metrics)
- Nginx Ingress Controller (TLS termination, IP filtering, GeoIP, WebSocket proxy)
- Kubernetes manifests (deployment, services, network policies, HPA, PDB)
- CI/CD pipeline (GitHub Actions — config validation, docker build, compliance checks)
- Monitoring stack integration (Prometheus, OpenTelemetry, Grafana)

**Processes:**
- API request routing and transformation
- Authentication and authorization (JWT validation, API key auth, RBAC)
- Rate limiting and traffic management (global, per-tenant, tiered)
- Circuit breaker management and failover
- Token revocation (bloom filter + Redis)
- Certificate management (mTLS, TLS)
- Configuration management (Flexible Configuration, GitOps)
- Incident detection and response at gateway level
- Change management for gateway configuration
- Monitoring, alerting, and security metrics collection

**Network Boundaries:**
- Ingress: External clients → Nginx Ingress → KrakenD (:8080)
- Egress: KrakenD → Backend services (LedgerOS :8081/:9081, Paymentos :8082, AtmOS :8088, Identos :8091, OnboardOS :8092, AccountOS :8093, FinanceOS :8095)
- Egress: KrakenD → Keycloak (JWKS validation)
- Egress: KrakenD → Redis (:6379)
- Egress: KrakenD → OTel Collector (:4317)
- Metrics: Prometheus → KrakenD (:8090)

### 3.2 Out of Scope

| Component | Reason | Covered By |
|-----------|--------|------------|
| Backend service internals | Separate ISMS per service | LedgerOS ISMS, Paymentos ISMS, etc. |
| Keycloak administration | Separate identity platform ISMS | Identos ISMS |
| Cloud provider physical infrastructure | CSP responsibility (shared model) | ISO 27017/27018 via provider |
| End-user devices/browsers | Client-side security | Not applicable |
| DNS infrastructure | External service | Cloud provider SLA |
| CI/CD runner infrastructure | GitHub-managed | GitHub SOC 2 |
| Redis cluster management | Infrastructure team | Platform ISMS |
| Prometheus/Grafana administration | Monitoring team | Observability ISMS |

### 3.3 Interfaces and Dependencies

| Interface | Direction | Dependency | Security Controls |
|-----------|-----------|------------|-------------------|
| Nginx Ingress → KrakenD | Inbound | TLS termination, IP filtering | A.8.20, A.8.21, A.8.24 |
| KrakenD → Keycloak | Outbound | JWKS key fetching | A.8.5, A.5.17 |
| KrakenD → Backend services | Outbound | API routing, mTLS | A.8.20, A.8.24, A.5.14 |
| KrakenD → Redis | Outbound | Rate limits, revocation, cache | A.8.3, A.8.6 |
| KrakenD → OTel Collector | Outbound | Telemetry export | A.8.15, A.8.16 |
| Prometheus → KrakenD | Inbound | Metrics scraping | A.8.16 |
| GitHub Actions → Gateway repo | Inbound | CI/CD pipeline | A.8.25, A.8.32 |

## 4. Applicability

This ISMS applies to:
- All personnel with access to gateway configuration or deployment
- All automated systems that interact with the gateway
- All environments: development, staging, production

## 5. Document Control

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | 2026-03-25 | Security Architect | Initial scope definition |

---

> **Cross-references:**
> - [Information Security Policy](information-security-policy.md)
> - [Interested Parties](interested-parties.md)
> - [ISMS Manual](isms-manual.md)
> - [Statement of Applicability](../risk/statement-of-applicability.md)
> - LedgerOS ISMS: `ledgeros/.base/plans/08-security/iso27000-security-framework.md`
