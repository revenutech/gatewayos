# CI — `ci-oci.yml`

## Objetivo

Workflow de validação para PRs e commits que tocam o track Basa. Não faz
deploy — apenas valida código, config, terraform e helm.

## Triggers

```yaml
on:
  pull_request:
    branches: [main, develop, staging]
    paths:
      - '.base/basa/**'
      - 'docker/Dockerfile.ubi9'
      - 'deployment/infra/oci/**'
      - 'k8s/helm/gateway/values-oci-*.yaml'
      - '.github/workflows/ci-oci.yml'
      - '.github/workflows/_reusable/**'
  push:
    branches: [develop, staging]
    paths:
      - (mesma lista)
```

`ci.yml` existente continua rodando sempre (cloud-agnóstico). `ci-oci.yml`
adiciona gates Basa-specific.

## Jobs

### 1. `lint-docs`

Valida markdown dos documentos do plano Basa.

```yaml
lint-docs:
  runs-on: ubuntu-latest
  steps:
    - uses: actions/checkout@v4
    - uses: DavidAnson/markdownlint-cli2-action@v15
      with:
        globs: '.base/basa/**/*.md'
        config: '.markdownlint.json'
```

### 2. `dockerfile-ubi-lint`

```yaml
dockerfile-ubi-lint:
  runs-on: ubuntu-latest
  steps:
    - uses: actions/checkout@v4
    - uses: hadolint/hadolint-action@v3.1.0
      with:
        dockerfile: docker/Dockerfile.ubi9
        failure-threshold: warning
```

### 3. `dockerfile-ubi-build` (só valida, não pusha)

```yaml
dockerfile-ubi-build:
  runs-on: ubuntu-latest
  needs: dockerfile-ubi-lint
  steps:
    - uses: actions/checkout@v4
    - name: Build UBI image (validate only)
      run: |
        docker build \
          -f docker/Dockerfile.ubi9 \
          --build-arg ENV=dev \
          -t gateway-basa:ci-${{ github.sha }} \
          .
    - name: Smoke test
      run: |
        # Verifica UID random compat
        docker run --rm --user $((RANDOM+1000000)) \
          gateway-basa:ci-${{ github.sha }} \
          krakend version
```

### 4. `terraform-validate`

```yaml
terraform-validate:
  runs-on: ubuntu-latest
  strategy:
    matrix:
      env: [dev, staging, production]
  steps:
    - uses: actions/checkout@v4
    - uses: hashicorp/setup-terraform@v3
      with:
        terraform_version: 1.10.0
    - name: Init (no backend)
      working-directory: deployment/infra/oci/environments/${{ matrix.env }}
      run: terraform init -backend=false
    - name: Validate
      working-directory: deployment/infra/oci/environments/${{ matrix.env }}
      run: terraform validate
    - name: Format check
      run: terraform fmt -check -recursive deployment/infra/oci/
```

### 5. `terraform-plan-dev` (opcional, em PR para `develop`)

```yaml
terraform-plan-dev:
  if: github.event_name == 'pull_request' && contains(github.event.pull_request.changed_files, 'deployment/infra/oci/')
  runs-on: ubuntu-latest
  permissions:
    contents: read
    id-token: write
    pull-requests: write
  environment: dev-oci
  steps:
    - uses: actions/checkout@v4
    - name: Configure OCI CLI
      uses: oracle-actions/configure-oci-cli@v1.3.2
      with:
        tenancy-ocid: ${{ secrets.OCI_TENANCY_OCID }}
        token-exchange-url: https://auth.${{ secrets.OCI_REGION_DEV }}.oraclecloud.com/v1/oauth2/token
    - uses: hashicorp/setup-terraform@v3
    - name: Init
      working-directory: deployment/infra/oci/environments/dev
      run: terraform init -backend-config=...
    - name: Plan
      working-directory: deployment/infra/oci/environments/dev
      run: terraform plan -no-color -out=plan.tfplan
    - name: Post plan as PR comment
      uses: actions/github-script@v7
      with:
        script: |
          const fs = require('fs');
          const plan = fs.readFileSync('deployment/infra/oci/environments/dev/plan.tfplan', 'utf8');
          github.rest.issues.createComment({
            issue_number: context.issue.number,
            owner: context.repo.owner,
            repo: context.repo.repo,
            body: '```\n' + plan.substring(0, 60000) + '\n```'
          });
```

### 6. `helm-lint-oci`

```yaml
helm-lint-oci:
  runs-on: ubuntu-latest
  strategy:
    matrix:
      env: [dev, staging, production]
  steps:
    - uses: actions/checkout@v4
    - uses: azure/setup-helm@v4
    - name: Lint
      run: |
        helm lint k8s/helm/gateway \
          -f k8s/helm/gateway/values-oci-${{ matrix.env }}.yaml
    - name: Template validate
      run: |
        helm template gateway k8s/helm/gateway \
          -f k8s/helm/gateway/values-oci-${{ matrix.env }}.yaml \
          > /tmp/rendered.yaml
        kubeconform -strict -ignore-missing-schemas /tmp/rendered.yaml
```

### 7. `trivy-fs`

Reusable workflow `.github/workflows/_reusable/trivy-scan.yml`:

```yaml
trivy-fs:
  uses: ./.github/workflows/_reusable/trivy-scan.yml
  with:
    scan-type: fs
    path: .
    severity: CRITICAL,HIGH
    ignore-unfixed: true
```

### 8. `config-audit` (compartilhado com `ci.yml`)

```yaml
config-audit:
  runs-on: ubuntu-latest
  steps:
    - uses: actions/checkout@v4
    - name: KrakenD config audit
      run: bash tools/config-audit/audit.sh --strict
```

Mesma lógica do track GCP (reutilizada).

## Paralelismo

Jobs independentes rodam em paralelo. `needs:` só onde há dependência real:

```
lint-docs, dockerfile-ubi-lint, terraform-validate, helm-lint-oci,
trivy-fs, config-audit  → todos em paralelo

dockerfile-ubi-build → needs: dockerfile-ubi-lint
terraform-plan-dev → needs: terraform-validate (opcional)
```

## Status check obrigatório

Branch protection em `main`/`staging`/`develop`:

- `ci-oci.yml / lint-docs` — required.
- `ci-oci.yml / dockerfile-ubi-build` — required.
- `ci-oci.yml / terraform-validate (matrix)` — required.
- `ci-oci.yml / helm-lint-oci (matrix)` — required.
- `ci-oci.yml / trivy-fs` — required.
- `ci-oci.yml / config-audit` — required.

## Decisões de design

1. **CI cobre ambos os tracks** sem sobreposição — `ci.yml` roda sempre
   (config KrakenD), `ci-oci.yml` roda só se paths Basa tocados.
2. **`dockerfile-ubi-build` no CI** valida sem push — detecta quebras
   cedo.
3. **Matrix por env** em TF + Helm — pega valores de cada env.
4. **Plan como PR comment** — preview antes do merge.
5. **hadolint como warning** — não bloqueia só por style.

## Controles ISO 27001

- A.8.9 — Configuration management (validate).
- A.8.25 — Secure development life cycle.
- A.8.28 — Secure coding.

## Checklist pronto-para-código

- [ ] `ci-oci.yml` criado conforme jobs acima.
- [ ] Reusable workflow `_reusable/trivy-scan.yml`.
- [ ] Branch protection atualizada com novos required checks.
- [ ] Matrix por env funciona (3 builds paralelos).
- [ ] Plan como comment em PR de TF.
- [ ] hadolint passes no Dockerfile.ubi9.
