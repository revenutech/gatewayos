# CI — `ci-oci.yml`

**Arquiteto Principal:** Gustavo Armoa

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

`ci.yml` cobre validações cloud-agnósticas (config KrakenD, lint de docs).
`ci-oci.yml` adiciona gates específicos do track Basa.

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
          --build-arg ENV=sqa \
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
      env: [sqa, uat, pro]
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

### 5. `terraform-plan-sqa` (opcional, em PR para `develop`)

```yaml
terraform-plan-sqa:
  if: github.event_name == 'pull_request' && contains(github.event.pull_request.changed_files, 'deployment/infra/oci/')
  runs-on: ubuntu-latest
  permissions:
    contents: read
    id-token: write
    pull-requests: write
  environment: sqa-oci
  steps:
    - uses: actions/checkout@v4
    - name: Configure OCI CLI
      uses: oracle-actions/configure-oci-cli@v1.3.2
      with:
        tenancy-ocid: ${{ secrets.OCI_TENANCY_OCID }}
        token-exchange-url: https://auth.${{ secrets.OCI_REGION_SQA }}.oraclecloud.com/v1/oauth2/token
    - uses: hashicorp/setup-terraform@v3
    - name: Init
      working-directory: deployment/infra/oci/environments/sqa
      run: terraform init -backend-config=...
    - name: Plan
      working-directory: deployment/infra/oci/environments/sqa
      run: terraform plan -no-color -out=plan.tfplan
    - name: Post plan as PR comment
      uses: actions/github-script@v7
      with:
        script: |
          const fs = require('fs');
          const plan = fs.readFileSync('deployment/infra/oci/environments/sqa/plan.tfplan', 'utf8');
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
      env: [sqa, uat, pro]
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

Valida o config KrakenD compilado antes do build.

## Paralelismo

Jobs independentes rodam em paralelo. `needs:` só onde há dependência real:

```
lint-docs, dockerfile-ubi-lint, terraform-validate, helm-lint-oci,
trivy-fs, config-audit  → todos em paralelo

dockerfile-ubi-build → needs: dockerfile-ubi-lint
terraform-plan-sqa → needs: terraform-validate (opcional)
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

1. **CI dividido em dois workflows** — `ci.yml` roda sempre (config
   KrakenD, docs), `ci-oci.yml` roda quando paths OCI/OpenShift/UBI9
   são tocados.
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

---

## Disclaimer — Recomendação Base

Este documento é uma **recomendação técnica de referência** elaborada como
baseline para o **Banco da Amazônia (BASA)** e **não constitui garantia
de segurança, conformidade regulatória ou funcionamento em produção**.

### Implementação por equipe especializada

A adoção e implementação efetiva deste plano **deve ser conduzida por
uma equipe DevSecOps especializada** nas seguintes tecnologias:

- **Oracle Cloud Infrastructure (OCI)** — arquitetura, IAM, networking,
  Vault, OCIR, observabilidade, compliance.
- **Red Hat OpenShift Container Platform (OCP)** — operação self-managed
  do cluster, SCC, Operators, Compliance Operator, atualizações.
- **Red Hat Enterprise Linux / UBI** — hardening, FIPS mode, supply
  chain de imagens, Red Hat Container Certification.

A ausência de profissionais com essa especialização inviabiliza a
execução segura deste plano.

### Governança de segurança — responsabilidade do Banco da Amazônia

A **governança de segurança da informação do Banco da Amazônia** deve
ser implementada, mantida e auditada com base na família de normas
**ISO/IEC 27000**:

- **ISO/IEC 27001:2022** — requisitos para sistemas de gestão de
  segurança da informação (ISMS).
- **ISO/IEC 27002:2022** — controles de segurança (Annex A, 93 controles).
- **ISO/IEC 27003** — diretrizes de implementação do ISMS.
- **ISO/IEC 27004** — monitoramento, medição, análise e avaliação de
  desempenho do ISMS.
- **ISO/IEC 27005** — gestão de riscos de segurança da informação.

Adicionalmente, **todas as boas práticas de segurança** aplicáveis ao
setor financeiro brasileiro devem ser incorporadas:

- NIST Cybersecurity Framework (CSF).
- CIS Benchmarks (Kubernetes, OpenShift, Red Hat Enterprise Linux).
- OWASP Top 10 / ASVS / SAMM.
- Resoluções **BACEN** (nº 4.893/2021 — Política de Segurança Cibernética,
  Resolução Conjunta 6/2023, entre outras aplicáveis a instituições
  financeiras).
- **Lei Geral de Proteção de Dados (LGPD — Lei 13.709/2018)**.
- SANS Critical Security Controls.

### Autoridade final

**O Banco da Amazônia é a autoridade final** sobre:

- A adequação deste plano ao contexto regulatório, operacional e de
  negócio da instituição.
- A aprovação técnica e executiva de qualquer controle, arquitetura ou
  decisão descrita neste documento.
- A implementação, operação, auditoria e evolução contínua do programa
  de segurança da informação.
- A responsabilidade legal, regulatória e contratual decorrente do uso
  deste material.

Este documento **não substitui** parecer jurídico, auditoria
independente, avaliação de risco formal, nem aprovação do Comitê de
Segurança da Informação do Banco da Amazônia.
