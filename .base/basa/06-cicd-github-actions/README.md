# Fase 06 — CI/CD GitHub Actions

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
