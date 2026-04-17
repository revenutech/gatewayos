# OCI OIDC Federation — GitHub Actions

## Objetivo

Configurar autenticação federada entre **GitHub Actions** e **OCI
Identity Domain** via OIDC, eliminando API keys estáticas. Equivalente
ao Workload Identity Federation do GCP.

## Equivalência

| GCP WIF | OCI OIDC Federation |
|---|---|
| Workload Identity Pool | Identity Domain |
| Workload Identity Provider (OIDC) | Identity Provider (OIDC) |
| Service Account impersonation | Group → Dynamic Group → Policy |
| `google-github-actions/auth@v2` | `oracle-actions/configure-oci-cli` + claim mapping |
| ID token troca por access token | ID token troca por UPST (User Principal Session Token) |

## Arquitetura

```
GitHub Actions (workflow)
        │ id_token: write (OIDC)
        ▼
OIDC token (issuer: https://token.actions.githubusercontent.com)
        │
        ▼
OCI Identity Domain → Identity Provider (GitHub)
        │ valida token + extrai claims (repo, sub, ref)
        ▼
Mapeia para GitHub "user" federado em OCI
        │
        ▼
User é membro de Group (ex: gateway-ci-dev-group)
        │
        ▼
Group → Policy (permissões no compartment)
        │
        ▼
UPST emitido → CLI OCI autenticado → Terraform/oci CLI rodam
```

## Setup one-time (no OCI console + Terraform)

### 1. Criar Identity Domain IdP de GitHub

Em `Identity & Security → Domains → Default → Identity Providers`:

```yaml
kind: OIDC
name: GitHub-Actions
metadata_url: https://token.actions.githubusercontent.com/.well-known/openid-configuration
issuer: https://token.actions.githubusercontent.com
client_id: {github-org}/{repo}            # ex: revenutech/revenu-platform-gateway
jwt_signature_algorithm: RS256
```

### 2. Criar grupos por env

- `gateway-ci-dev-group`
- `gateway-ci-staging-group`
- `gateway-ci-prod-group`

### 3. IdP Rules — JIT provisioning

No Identity Domain, "Assign a group rule" para mapear automaticamente GH
→ grupo OCI baseado em claims:

**Rule dev:**
```
claim: sub
operator: matches
value: repo:revenutech/revenu-platform-gateway:ref:refs/heads/develop
group: gateway-ci-dev-group
```

**Rule staging:**
```
claim: sub
value: repo:revenutech/revenu-platform-gateway:ref:refs/heads/staging
group: gateway-ci-staging-group
```

**Rule prod:**
```
claim: sub
operator: starts_with
value: repo:revenutech/revenu-platform-gateway:ref:refs/tags/v
group: gateway-ci-prod-group
```

Amarra execução a branches/tags específicos.

### 4. Policies OCI

```
Allow group 'Default'/gateway-ci-dev-group to manage all-resources in compartment gateway-basa-dev
Allow group 'Default'/gateway-ci-dev-group to manage object-family in compartment revenu-platform-shared where target.bucket.name='revenu-platform-tf-state-oci' and target.object.name like 'gateway-basa/dev/*'

Allow group 'Default'/gateway-ci-staging-group to manage all-resources in compartment gateway-basa-staging
...

Allow group 'Default'/gateway-ci-prod-group to manage repos in compartment gateway-basa-prod where target.repo.name='gateway-basa-prod'
Allow group 'Default'/gateway-ci-prod-group to use cluster-ocp:gateway-basa-prod-ocp in compartment gateway-basa-prod
Allow group 'Default'/gateway-ci-prod-group to manage object-family in compartment revenu-platform-shared where target.bucket.name='revenu-platform-tf-state-oci' and target.object.name like 'gateway-basa/prod/*'
```

**Prod policy mais restrita** — não `manage all-resources`, apenas o
necessário para deploy (registry push + cluster access + tfstate).

## Uso no workflow GitHub Actions

### Permissions

```yaml
permissions:
  contents: read
  id-token: write       # obrigatório para OIDC
  packages: write       # para OCIR push via GHCR-like flows (opcional)
```

### Step — configurar OCI CLI

```yaml
- name: Configure OCI CLI (OIDC)
  uses: oracle-actions/configure-oci-cli@v1.3.2
  with:
    domain: default
    tenancy-ocid: ${{ secrets.OCI_TENANCY_OCID }}
    token-exchange-url: https://auth.${{ secrets.OCI_REGION }}.oraclecloud.com/v1/oauth2/token
    # audience detectada automaticamente
```

### Step — verificar sessão

```yaml
- name: Verify OCI auth
  run: |
    oci iam user get --user-id ${{ secrets.OCI_USER_OCID_CI }}
```

### Step — docker login OCIR

```yaml
- name: Login OCIR
  run: |
    TOKEN=$(oci raw-request --http-method POST \
      --target-uri "https://identity.${{ secrets.OCI_REGION }}.oraclecloud.com/20160918/auth-tokens" \
      --request-body '{...}' | jq -r .data.token)
    echo "$TOKEN" | docker login -u "${TENANCY_NS}/${USER_NAME}" --password-stdin gru.ocir.io
```

Alternativa: `OCI_CLI_AUTH=instance_principal` + docker helper. Depende
de versão do CLI.

### Step — kubeconfig OpenShift

```yaml
- name: Get OCP kubeconfig
  run: |
    oci secrets secret-bundle get \
      --secret-id ${{ secrets.OCP_KUBECONFIG_SECRET_OCID }} \
      --query 'data."secret-bundle-content".content' --raw-output \
      | base64 -d > $HOME/.kube/config
    chmod 600 $HOME/.kube/config
```

Kubeconfig fica armazenado em **OCI Vault Secret** (atualizado pelo
Terraform Fase 02) — evita commitar ou mover manualmente.

Alternativa: **ServiceAccount token** curto, projetado para CI. Detalhe
em `cd-dev-oci.md`.

## Secrets GitHub (nomes fixos — ver Fase 00 `naming-conventions.md`)

| Nome | Uso |
|---|---|
| `OCI_TENANCY_OCID` | Tenancy OCID |
| `OCI_REGION_DEV` / `_STAGING` / `_PROD` | Região (ex: `sa-saopaulo-1`) |
| `OCI_USER_OCID_CI` | (se aplicável) user federado |
| `OCIR_REPO_DEV` / `_STAGING` / `_PROD` | URL do registry |
| `OCP_KUBECONFIG_SECRET_OCID_DEV` / ... | OCID do Secret Vault com kubeconfig |
| `OCP_CLUSTER_API_DEV` / ... | endpoint API OCP (informacional) |
| `SLACK_WEBHOOK_URL` | reutilizado |

## Audit & troubleshooting

- **OCI Audit** grava cada troca de token + cada request feito (A.8.15).
- **GitHub Actions** log mostra OIDC subject usado.
- **Falha comum**: subject/claim não bateu regra IdP → checar log do
  Identity Domain "Identity Provider Events".

## Cross-account boundary

Se quisermos separar **tenancy dev** de **tenancy prod** (isolamento máximo):
- Cada tenancy tem seu Identity Domain + IdP GitHub.
- Workflow diferente para prod usa `OCI_TENANCY_OCID_PROD`.
- Aumenta isolamento; aumenta complexidade operacional.

**V1 adota:** 1 tenancy, 3 compartments (Fase 02). 2 tenancies fica
proposta para v2 caso governança exigir.

## Decisões de design

1. **OIDC federation**, não API keys.
2. **JIT provisioning via IdP Rules** — user OCI efêmero.
3. **Rules por ref** — dev/staging/prod amarrados a branch/tag específico.
4. **Prod com policy mínima** (não manage all-resources).
5. **Kubeconfig em Vault** — não em secret GitHub (rotacionável por TF).
6. **1 tenancy v1** — 2 tenancies v2 se exigido.

## Controles ISO 27001

- A.5.15 — Access control.
- A.5.16 — Identity management.
- A.5.17 — Authentication information (zero keys).
- A.8.2 — Privileged access rights.
- A.8.5 — Secure authentication.

## Checklist pronto-para-código

- [ ] Identity Domain IdP GitHub configurado.
- [ ] 3 groups + rules por env criados.
- [ ] Policies OCI aplicadas (mais restritas em prod).
- [ ] Secrets GitHub populados (ver nomes).
- [ ] Workflow PoC roda `oci iam user get` com sucesso.
- [ ] Kubeconfig de cada env gravado em Vault Secret.
