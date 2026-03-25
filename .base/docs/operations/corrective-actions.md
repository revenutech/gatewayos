---
title: "Corrective Actions Register — API Gateway"
iso_ref: "ISO/IEC 27001:2022 Clause 10.1-10.2"
version: "1.0"
status: Active
owner: Compliance Officer
classification: Confidential
---

# Corrective Actions Register — API Gateway

## Active Corrective Actions

| ID | Date | Source | Nonconformity | Root Cause | Corrective Action | Owner | Due | Status |
|----|------|--------|---------------|------------|-------------------|-------|-----|--------|
| CA-001 | 2026-03-25 | Initial assessment | `roles_key_is_nested` missing in RBAC endpoints | Keycloak nested claims not documented in KrakenD CE | Added `roles_key_is_nested: true` to all 14 RBAC endpoints | Sec Architect | 2026-03-25 | Closed |
| CA-002 | 2026-03-25 | Initial assessment | Bloom filter FPR too high (0.001) | Default value not tuned for scale | Reduced to 0.0000001 (1 in 10M) | Sec Architect | 2026-03-25 | Closed |
| CA-003 | 2026-03-25 | Risk assessment | Supply chain risk (R09) — no SBOM | Image scanning not in CI pipeline | Plan: Add Trivy scanning to CI | DevSecOps | 2026-06-30 | Open |
| CA-004 | 2026-03-25 | Risk assessment | Redis SPOF (R16) | Single Redis instance | Plan: Migrate to Redis Sentinel/Cluster | DevSecOps | 2026-06-30 | Open |

## Closed Corrective Actions

| ID | Date Opened | Date Closed | Description | Verification |
|----|-------------|-------------|-------------|-------------|
| CA-001 | 2026-03-25 | 2026-03-25 | RBAC nested roles fix | Commit `9cd7281`, all endpoints verified |
| CA-002 | 2026-03-25 | 2026-03-25 | Bloom filter FPR | Commit `9cd7281`, `bloom_filter.tmpl` updated |

## Process

1. **Identify:** Nonconformity found via audit, incident, or monitoring
2. **Analyze:** Root cause analysis (5-Whys)
3. **Plan:** Define corrective action with owner and due date
4. **Implement:** Execute corrective action
5. **Verify:** Confirm effectiveness (re-test, audit evidence)
6. **Close:** Update register, link to evidence (Git commit, test result)
