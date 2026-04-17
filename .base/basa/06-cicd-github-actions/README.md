# Fase 06 — CI/CD GitHub Actions

Esteira de pipelines GitHub Actions do track Basa: OIDC Federation com
OCI (sem keys estáticas), CI validation, CD dev/staging/prod, compliance
ISO e estratégia de rollback. Paridade com `cd-*-gcp.yml` atual.

## Arquivos

| Documento | Foco |
|---|---|
| [oci-oidc-federation.md](oci-oidc-federation.md) | Configuração GitHub → OCI Identity Domain federation |
| [ci-oci.md](ci-oci.md) | `ci-oci.yml` — validate, lint, trivy fs, helm lint, tf validate |
| [cd-dev-oci.md](cd-dev-oci.md) | `cd-dev-oci.yml` — push `develop` → build + push OCIR + helm upgrade |
| [cd-staging-oci.md](cd-staging-oci.md) | `cd-staging-oci.yml` — push `staging` → + cosign sign + smoke |
| [cd-production-oci.md](cd-production-oci.md) | `cd-production-oci.yml` — tag `v*.*.*` → approval + SBOM + Trivy + cosign attest + atomic helm + rollback |
| [compliance-oci.md](compliance-oci.md) | `compliance-oci.yml` — validação ISMS + ISO check (delta do atual) |
| [rollback-strategy.md](rollback-strategy.md) | Rollback automático, manual, retention de versões Helm |

## Arquivos alvo no repo (quando executar)

```
.github/workflows/
├── ci-oci.yml                  # NOVO
├── cd-dev-oci.yml              # NOVO
├── cd-staging-oci.yml          # NOVO
├── cd-production-oci.yml       # NOVO
├── compliance-oci.yml          # NOVO
├── ci.yml                      # já existente — cloud-agnóstico, mantém
├── cd-dev-gcp.yml              # já existente
├── cd-staging-gcp.yml          # já existente
├── cd-production-gcp.yml       # já existente
└── compliance.yml              # já existente — mantém, complementado por compliance-oci.yml
```

Adicionalmente:

```
.github/workflows/_reusable/
├── cosign-sign.yml             # reusable workflow — sign + attest
├── trivy-scan.yml              # reusable — scan fs/image/config
└── sbom-publish.yml            # reusable — gera + publica SBOM
```

## Equivalência com track GCP

| GCP (atual) | Basa |
|---|---|
| `cd-dev-gcp.yml` (push `develop`) | `cd-dev-oci.yml` (push `develop`) |
| `cd-staging-gcp.yml` (push `staging`) | `cd-staging-oci.yml` (push `staging`) |
| `cd-production-gcp.yml` (tag `v*.*.*`) | `cd-production-oci.yml` (tag `v*.*.*`) |
| `compliance.yml` | `compliance-oci.yml` (adiciona checks OCI-specific) |
| Workload Identity Federation (WIF) | OCI OIDC Federation |
| `google-github-actions/auth@v2` | `oracle-actions/configure-oci-cli` + OIDC |
| AR push via `gcloud auth configure-docker` | OCIR push via token OCI |
| `helm upgrade` em GKE | `helm upgrade` em OpenShift |

## Concurrency & triggers

| Workflow | Trigger | Branch / Tag |
|---|---|---|
| `ci-oci.yml` | `pull_request` + `push` em qualquer branch que toque `.base/basa/` ou OCI paths | — |
| `cd-dev-oci.yml` | `push` | `develop` |
| `cd-staging-oci.yml` | `push` | `staging` |
| `cd-production-oci.yml` | `push` tag + `workflow_dispatch` | `v*.*.*` |
| `compliance-oci.yml` | `push` + `pull_request` em main/develop/staging + `schedule` diário | — |

## Environments (GitHub)

| Environment | Approval? | Secrets específicos |
|---|---|---|
| `dev-oci` | não | OCI OIDC config dev |
| `staging-oci` | não (ou 1 reviewer) | idem staging |
| `production-oci` | **sim, 2 reviewers** + branch protection | idem prod |

## Princípios

1. **Zero key estática** — OCI OIDC federation em todo workflow.
2. **Reusable workflows** — cosign/trivy/sbom evitam duplicação.
3. **Fail-fast em CI**, **fail-safe em CD** (rollback automático).
4. **Paridade com GCP** — mesmos gates, mesmas assinaturas, mesmas saídas.
5. **Compliance CI separado** — roda em cada PR, não só em deploy.

## Checklist de fechamento da Fase 06

- [ ] 5 workflows especificados com YAML mínimo render-ready.
- [ ] OIDC federation documentada end-to-end (OCI → GitHub).
- [ ] Secrets GitHub listados (naming já em Fase 00).
- [ ] Reusable workflows definidos.
- [ ] Rollback auto + manual documentados.
- [ ] Paridade com GCP validada (mesmo comportamento, outputs).

## Controles ISO 27001

- A.5.26 — Response to security incidents (rollback).
- A.8.9 — Configuration management (imagens/versões determinísticas).
- A.8.25 — Secure development life cycle.
- A.8.28 — Secure coding (lint + validation).
- A.8.32 — Change management (approval gates).
