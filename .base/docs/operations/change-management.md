---
title: "Change Management Procedure — API Gateway"
iso_ref: "ISO 27001:2022 A.8.32, Cl. 6.3"
version: "1.0"
status: Active
owner: DevSecOps Lead
classification: Internal
---

# Change Management Procedure — API Gateway

## 1. Change Categories

| Category | Examples | Approval | Deployment |
|----------|---------|----------|------------|
| **Standard** | Endpoint additions, rate limit tuning, CB config | 1 reviewer (CODEOWNERS) | Normal CI/CD |
| **Normal** | New backend module, security policy changes, auth changes | Security Architect review | CI/CD + staging validation |
| **Emergency** | Security patch, incident remediation, cert rotation | Post-hoc review within 24h | Fast-track deploy |

## 2. Change Process

```
1. RFC (Pull Request)
   └── Author creates PR with description + ISO control references
2. Review
   └── CODEOWNERS review (Security Architect for security-impacting)
   └── CI pipeline: config check → lint → audit → docker build → compliance
3. Approval
   └── PR approved by required reviewers
4. Deploy
   └── Merge to main → CI builds image → Config hash updated → Rolling update
5. Verify
   └── Health check → Metrics baseline comparison → 30min watch period
6. Record
   └── Git commit history serves as change record
```

## 3. Security-Impacting Changes

Require Security Architect review (enforced via CODEOWNERS):
- `krakend/partials/jwt_validator.tmpl`
- `krakend/partials/security/*`
- `krakend/partials/lua/security_policies.lua`
- `krakend/partials/lua/token_revocation.lua`
- `k8s/policies/*`
- `k8s/manifests/ingress.yaml`
- `k8s/manifests/mtls-certificates.yaml`

## 4. Rollback

```
1. Identify bad commit: git log --oneline
2. Revert: git revert <commit>
3. CI validates reverted config
4. Automatic rolling update (maxUnavailable: 0)
5. Post-rollback: update corrective actions register
```
