---
title: "Internal Audit Procedure — API Gateway ISMS"
iso_ref: "ISO/IEC 27001:2022 Clause 9.2"
version: "1.0"
status: Active
owner: Compliance Officer
classification: Internal
---

# Internal Audit Procedure — API Gateway ISMS

## 1. Audit Program

| Aspect | Detail |
|--------|--------|
| Frequency | Annual (minimum); after significant changes |
| Scope | All ISMS processes and applicable Annex A controls |
| Auditor | Compliance Officer (independent of audited area) |
| Method | Checklist-based against controls-matrix.md |
| Standard | ISO 19011:2018 (Guidelines for auditing management systems) |

## 2. Audit Checklist (Abbreviated)

### ISMS Processes (Cl. 4-10)
- [ ] Scope statement current and approved?
- [ ] Security policy reviewed within 6 months?
- [ ] RACI matrix reflects current team?
- [ ] Risk register reviewed within 3 months?
- [ ] SoA aligned with current controls?
- [ ] Security metrics collected and reported?
- [ ] Management review conducted this quarter?
- [ ] Corrective actions tracked to closure?

### Technical Controls (A.8)
- [ ] JWT validation working? (test with expired/invalid token)
- [ ] Rate limiting enforced? (test exceeding limit)
- [ ] Circuit breakers functional? (test backend failure)
- [ ] TLS 1.2+ enforced? (test with TLS 1.0/1.1)
- [ ] mTLS certificates valid and not expiring soon?
- [ ] Network policies applied? (`kubectl get networkpolicy`)
- [ ] Logs being collected? (check OTel + Prometheus)
- [ ] Config audit passing? (`tools/config-audit/audit.sh --strict`)

### Automated Auditing (CI)
- [ ] CI compliance job passing?
- [ ] Config validation passing?
- [ ] JSON lint passing?
- [ ] OpenAPI spec generating successfully?

## 3. Audit Report Template

```
INTERNAL AUDIT REPORT — API Gateway ISMS
Date: [DATE]
Auditor: [NAME]
Scope: [DESCRIPTION]

FINDINGS:
  Critical:  [count]
  Major:     [count]
  Minor:     [count]
  Observations: [count]

[Detailed findings table]

CONCLUSION: [Conforming / Conforming with observations / Non-conforming]
NEXT AUDIT: [DATE]
```

## 4. Non-conformity Handling

1. Finding documented with evidence
2. Root cause analysis (5-Whys)
3. Corrective action proposed
4. Logged in `corrective-actions.md`
5. Tracked to closure with verification
