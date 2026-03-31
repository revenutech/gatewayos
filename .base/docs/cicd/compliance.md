# ISO 27001 Compliance Pipeline

File: `.github/workflows/compliance.yml`
Triggers: push to main/develop, PR to main

## Checks

### A.8.9 — Configuration Management

Config audit via `tools/config-audit/audit.sh --strict`:
- Environment consistency
- Security settings validation
- CORS configuration check

### A.8.25 — Secure Development

KrakenD config syntax validation:
```bash
krakend check -c /etc/krakend/krakend.tmpl
```

### A.8.9 — JSON Validity

Lints all settings JSON files with `python3 -m json.tool`.

### A.5.28 — Evidence Collection

Verifies 15 mandatory ISMS documents exist:

| Category | Documents |
|----------|-----------|
| ISMS | scope-statement.md, information-security-policy.md, roles-responsibilities.md, interested-parties.md, isms-manual.md |
| Risk | risk-methodology.md, risk-register.md, statement-of-applicability.md, threat-model.md |
| Compliance | controls-matrix.md |
| Operations | incident-response-plan.md, business-continuity-plan.md, change-management.md, internal-audit-procedure.md, corrective-actions.md |

### A.8.5 — Authentication Security

Verifies JWT validator settings:
- `failed_jwk_key_cooldown` present in jwt_validator.tmpl
- `roles_key_is_nested` present in RBAC endpoints

### A.8.20 — Network Security

Verifies network policy files exist:
- `k8s/policies/krakend-ingress.yaml`
- `k8s/policies/krakend-egress.yaml`
- `k8s/policies/krakend-ip-filter.yaml`
