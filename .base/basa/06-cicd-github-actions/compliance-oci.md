# Compliance — `compliance-oci.yml`

## Objetivo

Validação ISO 27001 específica do track Basa. Roda em **todo PR** e
**diariamente**, complementando validações de `ci.yml` cloud-agnósticas.

## Trigger

```yaml
on:
  pull_request:
    branches: [main, develop, staging]
    paths:
      - '.base/basa/**'
      - 'docker/Dockerfile.ubi9'
      - 'deployment/infra/oci/**'
      - 'k8s/helm/gateway/values-oci-*.yaml'
  push:
    branches: [main, develop, staging]
  schedule:
    - cron: '0 5 * * *'          # diário 05:00 UTC
```

## Jobs

### 1. `iso-documents-basa`

Verifica que os documentos da Fase 07 (ISO delta OCI) existem:

```yaml
iso-documents-basa:
  runs-on: ubuntu-latest
  steps:
    - uses: actions/checkout@v4
    - name: Verify Basa ISO documents
      run: |
        MISSING=0
        for doc in \
          ".base/basa/07-iso27001/controls-matrix-delta.md" \
          ".base/basa/07-iso27001/soa-oci.md" \
          ".base/basa/07-iso27001/risk-register-delta.md" \
          ".base/basa/07-iso27001/evidence-mapping.md" \
          ".base/basa/00-foundation/scope.md" \
          ".base/basa/00-foundation/adr-001-openshift-vs-oke.md"; do
          if [ ! -f "$doc" ]; then
            echo "MISSING: $doc"
            MISSING=$((MISSING + 1))
          fi
        done
        [ "$MISSING" -eq 0 ] || exit 1
```

### 2. `adr-integrity`

Valida que ADRs têm frontmatter consistente (Status, Data, Decisores):

```yaml
adr-integrity:
  runs-on: ubuntu-latest
  steps:
    - uses: actions/checkout@v4
    - name: Check ADRs
      run: |
        for adr in .base/basa/**/adr-*.md; do
          grep -q '^- \*\*Status:\*\*' "$adr" || { echo "$adr missing Status"; exit 1; }
          grep -q '^- \*\*Data:\*\*' "$adr" || { echo "$adr missing Data"; exit 1; }
          grep -q '^- \*\*Decisores:\*\*' "$adr" || { echo "$adr missing Decisores"; exit 1; }
        done
```

### 3. `annex-a-references`

Scanner que garante que **toda pasta de fase** referencia controles
Annex A:

```yaml
annex-a-references:
  runs-on: ubuntu-latest
  steps:
    - uses: actions/checkout@v4
    - name: Check Annex A references
      run: |
        for phase in .base/basa/0*/; do
          if ! grep -rq "A\\.[0-9]" "$phase"; then
            echo "Phase $phase does NOT reference any Annex A control"
            exit 1
          fi
        done
```

### 4. `oci-specific-checks`

Checks que o track Basa cumpra padrões definidos em Fase 00/02:

```yaml
oci-specific-checks:
  runs-on: ubuntu-latest
  steps:
    - uses: actions/checkout@v4

    # Terraform — defined tags presentes
    - name: defined_tags in all modules
      run: |
        for tf in deployment/infra/oci/modules/**/main.tf; do
          grep -q 'defined_tags' "$tf" || { echo "$tf missing defined_tags"; exit 1; }
        done

    # Helm — values-oci-*.yaml com bloco openshift
    - name: Helm values consistent
      run: |
        for f in k8s/helm/gateway/values-oci-*.yaml; do
          grep -q 'openshift:' "$f" || { echo "$f missing openshift block"; exit 1; }
        done

    # Dockerfile.ubi9 — labels obrigatórias RH cert
    - name: Dockerfile.ubi9 labels
      run: |
        for label in name vendor version release summary description; do
          grep -q "LABEL $label\|$label=" docker/Dockerfile.ubi9 \
            || { echo "Dockerfile.ubi9 missing LABEL $label"; exit 1; }
        done
```

### 5. `jwt-fips-crypto`

Reaproveita checks do `compliance.yml` — valida que JWT config não
regrediu:

```yaml
jwt-crypto:
  runs-on: ubuntu-latest
  steps:
    - uses: actions/checkout@v4
    - name: A.8.5 — JWT security
      run: |
        grep -q "failed_jwk_key_cooldown" krakend/templates/jwt_validator.tmpl
        grep -q "roles_key_is_nested" krakend/templates/endpoint_ledger_v1.tmpl
    - name: A.8.24 — RS256 algorithm
      run: |
        grep -q '"alg": "RS256"' krakend/partials/jwt_validator.tmpl \
          || grep -q "alg.*RS256" krakend/templates/jwt_validator.tmpl
```

### 6. `soa-vs-controls-matrix`

Valida que SoA está coerente com controls-matrix (sem controle em
controls-matrix ausente em SoA):

```yaml
soa-vs-matrix:
  runs-on: ubuntu-latest
  steps:
    - uses: actions/checkout@v4
    - name: SoA coverage
      run: |
        python3 - <<'PY'
        import re
        matrix = open('.base/basa/07-iso27001/controls-matrix-delta.md').read()
        soa = open('.base/basa/07-iso27001/soa-oci.md').read()
        controls_in_matrix = set(re.findall(r'A\.\d+\.\d+', matrix))
        controls_in_soa = set(re.findall(r'A\.\d+\.\d+', soa))
        missing = controls_in_matrix - controls_in_soa
        if missing:
            print("SoA missing controls:", missing)
            exit(1)
        print("SoA covers all matrix controls.")
        PY
```

### 7. `cosign-policy-review`

Check que policy ClusterImagePolicy está documentada (não ativa, mas
presente):

```yaml
cosign-policy-review:
  runs-on: ubuntu-latest
  steps:
    - uses: actions/checkout@v4
    - name: Policy doc exists
      run: |
        grep -q "ClusterImagePolicy" .base/basa/05-security-supplychain/cosign-keyless-oidc.md
```

### 8. `trivy-config-scan` (diário)

Roda `trivy config` no IaC:

```yaml
trivy-config:
  runs-on: ubuntu-latest
  steps:
    - uses: actions/checkout@v4
    - uses: aquasecurity/trivy-action@master
      with:
        scan-type: config
        scan-ref: .
        severity: CRITICAL,HIGH,MEDIUM
        format: sarif
        output: trivy-config.sarif
        exit-code: 0              # não bloqueia, apenas reporta
    - uses: github/codeql-action/upload-sarif@v3
      if: always()
      with:
        sarif_file: trivy-config.sarif
        category: trivy-config-daily
```

### 9. `compliance-report` (diário)

Gera artifact resumindo checks do dia para auditoria:

```yaml
compliance-report:
  runs-on: ubuntu-latest
  needs: [iso-documents-basa, adr-integrity, annex-a-references, oci-specific-checks, jwt-crypto, soa-vs-matrix]
  if: github.event_name == 'schedule'
  steps:
    - uses: actions/checkout@v4
    - name: Generate report
      run: |
        cat > compliance-report.md <<EOF
        # Compliance Daily Report — $(date -u +%Y-%m-%d)

        ## Checks

        - ISO documents: ✅
        - ADR integrity: ✅
        - Annex A refs: ✅
        - OCI-specific: ✅
        - JWT crypto: ✅
        - SoA coverage: ✅

        ## Commit
        ${{ github.sha }}
        EOF
    - uses: actions/upload-artifact@v4
      with:
        name: compliance-report-${{ github.run_id }}
        path: compliance-report.md
        retention-days: 2555             # 7 anos
```

## Status checks obrigatórios

Em `main`/`develop`/`uat`:
- `compliance-oci.yml / iso-documents-basa` — required.
- `compliance-oci.yml / adr-integrity` — required.
- `compliance-oci.yml / oci-specific-checks` — required.
- `compliance-oci.yml / soa-vs-matrix` — required (quando Fase 07
  publicada).

## Retenção

Artifacts `compliance-report-*` retidos por **7 anos** (A.5.33).

## Decisões de design

1. **Separado de `compliance.yml`** — evita PR em main virar giant check.
2. **Scheduled daily** — detecta drift (ex: doc removido acidentalmente).
3. **Retention 7 anos** em reports — compliance-grade evidência.
4. **Checks leves** — sem dependência de cluster; puramente estáticos.
5. **Bloqueante em PR** — time não consegue merger sem documentos ISO.

## Controles ISO 27001

- A.5.28 — Collection of evidence.
- A.5.33 — Protection of records.
- A.5.35 — Independent review of information security.
- A.5.36 — Compliance with policies.
- A.8.9 — Configuration management.

## Checklist pronto-para-código

- [ ] Workflow `.github/workflows/compliance-oci.yml` criado.
- [ ] 9 jobs rodando em paralelo.
- [ ] Retention 7 anos em compliance-report artifact.
- [ ] Branch protection inclui novos checks.
- [ ] Failure em iso-documents-basa bloqueia merge.
