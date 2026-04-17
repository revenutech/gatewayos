# Naming Conventions — Track Basa

Regras uniformes para nome, tags e labels de todo recurso do track Basa.
Serve de contrato entre Terraform, Helm, pipelines e runbooks.

## Regra mãe

Todo recurso carrega no nome (quando o provedor permite) o prefixo
**`gateway-basa-{env}-`**, com `env ∈ {dev, staging, prod}`. O sufixo
`-basa-` distingue do track GCP (`gateway-{env}-*`) e evita colisão de
ferramentas / scripts que varrem múltiplos ambientes.

## OCI — nomes de recurso

| Recurso | Padrão | Exemplo |
|---|---|---|
| Compartment | `gateway-basa-{env}` | `gateway-basa-dev` |
| VCN | `gateway-basa-{env}-vcn` | `gateway-basa-dev-vcn` |
| Subnet | `gateway-basa-{env}-subnet-{role}` (`role ∈ app,lb,bastion`) | `gateway-basa-dev-subnet-app` |
| NSG | `gateway-basa-{env}-nsg-{role}` | `gateway-basa-dev-nsg-app` |
| Route table | `gateway-basa-{env}-rt-{role}` | `gateway-basa-dev-rt-app` |
| NAT gateway | `gateway-basa-{env}-nat` | `gateway-basa-dev-nat` |
| IGW | `gateway-basa-{env}-igw` | `gateway-basa-dev-igw` |
| Bastion | `gateway-basa-{env}-bastion` | `gateway-basa-dev-bastion` |
| Vault | `gateway-basa-{env}-vault` | `gateway-basa-dev-vault` |
| KMS Key | `gateway-basa-{env}-key-{purpose}` (`purpose ∈ tfstate,app,backup`) | `gateway-basa-dev-key-app` |
| OCIR repo | `gateway-basa-{env}` | `gateway-basa-dev` |
| DNS zone | `{env}.oci.allenty.io` (dev/staging) · `oci.allenty.io` (prod) | `dev.oci.allenty.io` |
| Load Balancer | `gateway-basa-{env}-lb` | `gateway-basa-dev-lb` |
| Object Storage bucket | `revenu-platform-tf-state-oci` (único, prefixo por env no path) | — |

## OpenShift — namespaces, labels, annotations

| Recurso | Padrão | Exemplo |
|---|---|---|
| Namespace | `gateway-{env}` (sem prefixo `basa` — o cluster já é Basa) | `gateway-dev` |
| Cluster name | `gateway-basa-{env}-ocp` | `gateway-basa-dev-ocp` |
| Route host | `gateway.{env}.oci.allenty.io` (dev/staging) · `gateway.allenty.io` (prod, após cutover) | — |
| Service | `gateway` | — |
| Deployment | `gateway` | — |
| HPA | `gateway` | — |
| PDB | `gateway-pdb` | — |
| SCC | `gateway-scc` (custom se necessário; senão `restricted-v2`) | — |
| ServiceAccount | `gateway` | — |
| ConfigMap | `gateway-config` | — |

## Labels Kubernetes (todos recursos)

```yaml
app.kubernetes.io/name: gateway
app.kubernetes.io/instance: gateway-{env}
app.kubernetes.io/part-of: revenu-platform
app.kubernetes.io/component: api-gateway
app.kubernetes.io/managed-by: Helm
app.kubernetes.io/version: "{{ .Chart.AppVersion }}"
platform.revenu/track: basa
platform.revenu/env: {env}
platform.revenu/iso27001: "true"
```

## Tags OCI (freeform + defined)

**Defined tags** (namespace `revenu-platform`):

```
revenu-platform.app = gateway
revenu-platform.track = basa
revenu-platform.env = {dev|staging|prod}
revenu-platform.managed-by = terraform
revenu-platform.iso27001 = true
revenu-platform.owner = platform-team
revenu-platform.cost-center = platform
```

**Freeform tags** aceitas para debugging, não para lógica de billing.

## Git / Helm / Terraform

| Item | Padrão |
|---|---|
| Terraform module dir | `deployment/infra/oci/modules/{module}` |
| Terraform env dir | `deployment/infra/oci/environments/{env}` |
| Terraform state prefix | `gateway-basa/{env}` (no bucket `revenu-platform-tf-state-oci`) |
| Helm values | `k8s/helm/gateway/values-oci-{env}.yaml` |
| Helm release | `gateway` (mesmo que GCP; namespace isola) |
| Dockerfile | `docker/Dockerfile.ubi9` (novo) · `Dockerfile` mantém GCP |
| GH Actions workflows | `.github/workflows/{ci,cd-dev,cd-staging,cd-production,compliance}-oci.yml` |

## Branches e triggers

| Evento | Branch / Ref | Workflow |
|---|---|---|
| Validação | qualquer PR | `ci-oci.yml` |
| Dev deploy | push em `develop` | `cd-dev-oci.yml` |
| Staging deploy | push em `staging` | `cd-staging-oci.yml` |
| Prod deploy | tag `v*.*.*` ou `workflow_dispatch` | `cd-production-oci.yml` |
| Compliance | push/PR em `main`/`develop`/`staging` | `compliance-oci.yml` |

## Secrets GitHub (nomes fixos)

| Nome | Uso |
|---|---|
| `OCI_OIDC_PROVIDER_URL_DEV` / `_STAGING` / `_PROD` | URL do IdP federado OCI |
| `OCI_TENANCY_OCID` | OCID do tenancy |
| `OCI_USER_OCID_CI` | OCID do usuário CI (OIDC federated) |
| `OCI_REGION_DEV` / `_STAGING` / `_PROD` | ex: `sa-saopaulo-1` |
| `OCIR_REPO_DEV` / `_STAGING` / `_PROD` | ex: `gru.ocir.io/tenancy/gateway-basa-dev` |
| `OCP_CLUSTER_API_DEV` / `_STAGING` / `_PROD` | endpoint da API do cluster OpenShift |
| `OCP_SA_TOKEN_DEV` / `_STAGING` / `_PROD` | token curto do ServiceAccount CI (ou via OIDC exchange) |
| `SLACK_WEBHOOK_URL` | já existente — reutiliza |

## Regras gerais

1. **Sempre kebab-case** em nomes de recurso cloud; **camelCase** só em JSON/YAML onde já é padrão do provedor.
2. **Nunca** incluir segredos no nome.
3. **env sempre explícito** (`dev`/`staging`/`prod`) — proibido uso de `production` ou `stg`.
4. **Prefixo `gateway-basa-`** em recursos OCI protege contra conflito entre tracks.
5. **ISO 27001 tag `iso27001=true`** obrigatória em todo recurso auditável (controle A.5.12 — Classification of information).
