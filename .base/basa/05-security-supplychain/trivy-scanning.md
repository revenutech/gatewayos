# Trivy Scanning

**Arquiteto Principal:** Gustavo Armoa

## Objetivo

Scan de vulnerabilidades e misconfigurations em 3 dimensões:
**filesystem** (código + deps), **image** (container pushado), e
**config** (Helm, Dockerfile, Terraform). Bloqueio em CI baseado em
severity.

## Dimensões de scan

### 1. Filesystem — código + deps (pre-build)

```
trivy fs \
  --scanners vuln,misconfig,secret \
  --severity CRITICAL,HIGH \
  --ignore-unfixed \
  --format sarif \
  --output trivy-fs.sarif \
  .
```

Bloqueia CI se CVE CRITICAL/HIGH (fixable).

### 2. Image — imagem buildada (post-build, pre-push)

```
trivy image \
  --scanners vuln,secret,license \
  --severity CRITICAL,HIGH \
  --ignore-unfixed \
  --exit-code 1 \
  --format sarif \
  --output trivy-image.sarif \
  "${LOCAL_IMAGE_TAG}"
```

Scan **antes do push** evita publicar imagem vulnerável.

### 3. Config — IaC + Kubernetes manifests

```
trivy config \
  --severity CRITICAL,HIGH,MEDIUM \
  --format sarif \
  --output trivy-config.sarif \
  .
```

Inclui:
- `Dockerfile`/`Dockerfile.ubi9`
- `k8s/helm/gateway/templates/*.yaml` (após `helm template`)
- `deployment/infra/oci/**/*.tf`

## `.trivyignore` — convenção

### Lista base

```
# KrakenD CE upstream CVEs — mitigados por Lua JWE guard + go-jose patch
CVE-2026-34986
# (outros conforme .trivyignore atual)
```

### Deltas para UBI9

UBI9 traz seu próprio baseline de pacotes. Alguns CVEs específicos de
RPMs podem aparecer que não existiam em Alpine. Processo:

1. Build da imagem UBI9.
2. `trivy image` lista.
3. Para cada CVE CRITICAL/HIGH sem fix upstream:
   - Validar se afeta nossa superfície (KrakenD/Go não usa libs X).
   - Adicionar ao `.trivyignore` com **data + justificativa + review
     trimestral**.

Exemplo:
```
# krb5-libs — não usamos Kerberos; presente no UBI9 baseline
# Review: 2026-07-17 by @security-lead
CVE-2026-XXXXX
```

## Upload SARIF para GitHub

```yaml
- uses: github/codeql-action/upload-sarif@v3
  with:
    sarif_file: trivy-fs.sarif
    category: trivy-fs

- uses: github/codeql-action/upload-sarif@v3
  with:
    sarif_file: trivy-image.sarif
    category: trivy-image

- uses: github/codeql-action/upload-sarif@v3
  with:
    sarif_file: trivy-config.sarif
    category: trivy-config
```

Resultados visíveis em **GitHub Security tab → Code scanning alerts**.

## Policy por environment

| Env | Severity | Fixable only? | Block CI? |
|---|---|---|---|
| sqa | CRITICAL, HIGH | sim | não (warn) |
| uat | CRITICAL, HIGH | sim | sim |
| pro | CRITICAL, HIGH, MEDIUM | sim | sim |

Prod rodou adicional `MEDIUM` — protege contra acúmulo de dívida.

## License scan

```
trivy image --scanners license ...
```

Flag licenses "non-redistributable" (GPL family em libs distribuídas).
Revenu aceita Apache-2.0/MIT/BSD; GPL só permitido para componentes
isolados. Adicionar regra custom se necessário.

## Integração Red Hat security data

Trivy consome **Red Hat OVAL** automaticamente para imagens UBI —
acurácia maior que DB genérica. Nenhuma config extra necessária além de
rodar `trivy image`.

## Admission-time scan (opcional)

Alternativa a ACS: **Trivy Operator** in-cluster scaneia imagens rodando:

```yaml
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: trivy-operator
  namespace: trivy-system
spec:
  channel: alpha
  name: trivy-operator
  source: community-operators
```

Gera `VulnerabilityReport` CRs para cada pod rodando. Scoped para `pro`
v2.

## Integração com Grafana

Trivy Operator expõe `/metrics` Prometheus. Dashboard "Security posture"
no Grafana Operator (Fase 04) mostra CVE count por severity, aging, etc.

## Decisões de design

1. **Três dimensões de scan** — fs, image, config.
2. **`.trivyignore` com review trimestral** — não "set and forget".
3. **Prod adiciona MEDIUM** — reduz dívida.
4. **SARIF upload** — usa GitHub Security tab como UI.
5. **Trivy Operator opcional v2** — cluster-side scanning.
6. **Red Hat OVAL auto-habilitado** — acurácia UBI.

## Controles ISO 27001

- A.8.8 — Management of technical vulnerabilities.
- A.8.9 — Configuration management (trivy config scan).
- A.8.28 — Secure coding (secret scan).
- A.5.36 — Compliance with policies.

## Checklist pronto-para-código

- [ ] `trivy fs` em `ci-oci.yml`.
- [ ] `trivy image` em `cd-uat-oci.yml` e `cd-pro-oci.yml`.
- [ ] `trivy config` sobre `helm template` + `terraform show`.
- [ ] `.trivyignore` com comentários de review date + justificativa.
- [ ] SARIF upload ativo.
- [ ] Prod bloqueia MEDIUM.
- [ ] Trivy Operator opcional documentado para v2.

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
