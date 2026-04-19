# Fase 06 — CI/CD GitHub Actions

**Arquiteto Principal:** Gustavo Armoa

Esteira de pipelines GitHub Actions do track Basa: OIDC Federation com
OCI (sem keys estáticas), CI validation, CD sqa/uat/pro, compliance
ISO e estratégia de rollback.

## Arquivos

| Documento | Foco |
|---|---|
| [oci-oidc-federation.md](oci-oidc-federation.md) | Configuração GitHub → OCI Identity Domain federation |
| [ci-oci.md](ci-oci.md) | `ci-oci.yml` — validate, lint, trivy fs, helm lint, tf validate |
| [cd-sqa-oci.md](cd-sqa-oci.md) | `cd-sqa-oci.yml` — push `develop` → build + push OCIR + helm upgrade |
| [cd-uat-oci.md](cd-uat-oci.md) | `cd-uat-oci.yml` — push `staging` → + cosign sign + smoke |
| [cd-pro-oci.md](cd-pro-oci.md) | `cd-pro-oci.yml` — tag `v*.*.*` → approval + SBOM + Trivy + cosign attest + atomic helm + rollback |
| [compliance-oci.md](compliance-oci.md) | `compliance-oci.yml` — validação ISMS + ISO check (delta do atual) |
| [rollback-strategy.md](rollback-strategy.md) | Rollback automático, manual, retention de versões Helm |

## Arquivos alvo no repo (quando executar)

```
.github/workflows/
├── ci-oci.yml
├── cd-sqa-oci.yml
├── cd-uat-oci.yml
├── cd-pro-oci.yml
├── compliance-oci.yml
└── ci.yml                      # validações cloud-agnósticas (config KrakenD, lint)
```

Adicionalmente:

```
.github/workflows/_reusable/
├── cosign-sign.yml             # reusable workflow — sign + attest
├── trivy-scan.yml              # reusable — scan fs/image/config
└── sbom-publish.yml            # reusable — gera + publica SBOM
```

## Concurrency & triggers

| Workflow | Trigger | Branch / Tag |
|---|---|---|
| `ci-oci.yml` | `pull_request` + `push` em qualquer branch que toque `.base/basa/` ou OCI paths | — |
| `cd-sqa-oci.yml` | `push` | `develop` |
| `cd-uat-oci.yml` | `push` | `uat` |
| `cd-pro-oci.yml` | `push` tag + `workflow_dispatch` | `v*.*.*` |
| `compliance-oci.yml` | `push` + `pull_request` em main/develop/staging + `schedule` diário | — |

## Environments (GitHub)

| Environment | Approval? | Secrets específicos |
|---|---|---|
| `sqa-oci` | não | OCI OIDC config sqa |
| `uat-oci` | não (ou 1 reviewer) | idem uat |
| `pro-oci` | **sim, 2 reviewers** + branch protection | idem pro |

## Princípios

1. **Zero key estática** — OCI OIDC federation em todo workflow.
2. **Reusable workflows** — cosign/trivy/sbom evitam duplicação.
3. **Fail-fast em CI**, **fail-safe em CD** (rollback automático).
4. **Compliance CI separado** — roda em cada PR, não só em deploy.

## Checklist de fechamento da Fase 06

- [ ] 5 workflows especificados com YAML mínimo render-ready.
- [ ] OIDC federation documentada end-to-end (OCI → GitHub).
- [ ] Secrets GitHub listados (naming já em Fase 00).
- [ ] Reusable workflows definidos.
- [ ] Rollback auto + manual documentados.

## Controles ISO 27001

- A.5.26 — Response to security incidents (rollback).
- A.8.9 — Configuration management (imagens/versões determinísticas).
- A.8.25 — Secure development life cycle.
- A.8.28 — Secure coding (lint + validation).
- A.8.32 — Change management (approval gates).

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
