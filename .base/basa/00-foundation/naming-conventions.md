# Naming Conventions — Track Basa

**Arquiteto Principal:** Gustavo Armoa

Regras uniformes para nome, tags e labels de todo recurso do track Basa.
Serve de contrato entre Terraform, Helm, pipelines e runbooks.

## Regra mãe

Todo recurso carrega no nome (quando o provedor permite) o prefixo
**`gateway-basa-{env}-`**, com `env ∈ {sqa, uat, pro}`. O identificador
`basa` denota o track OCI/OpenShift/RH e evita colisão de ferramentas /
scripts que varrem múltiplos ambientes.

## OCI — nomes de recurso

| Recurso | Padrão | Exemplo |
|---|---|---|
| Compartment | `gateway-basa-{env}` | `gateway-basa-sqa` |
| VCN | `gateway-basa-{env}-vcn` | `gateway-basa-sqa-vcn` |
| Subnet | `gateway-basa-{env}-subnet-{role}` (`role ∈ app,lb,bastion`) | `gateway-basa-sqa-subnet-app` |
| NSG | `gateway-basa-{env}-nsg-{role}` | `gateway-basa-sqa-nsg-app` |
| Route table | `gateway-basa-{env}-rt-{role}` | `gateway-basa-sqa-rt-app` |
| NAT gateway | `gateway-basa-{env}-nat` | `gateway-basa-sqa-nat` |
| IGW | `gateway-basa-{env}-igw` | `gateway-basa-sqa-igw` |
| Bastion | `gateway-basa-{env}-bastion` | `gateway-basa-sqa-bastion` |
| Vault | `gateway-basa-{env}-vault` | `gateway-basa-sqa-vault` |
| KMS Key | `gateway-basa-{env}-key-{purpose}` (`purpose ∈ tfstate,app,backup`) | `gateway-basa-sqa-key-app` |
| OCIR repo | `gateway-basa-{env}` | `gateway-basa-sqa` |
| DNS zone | `{env}.oci.allenty.io` (sqa/uat) · `oci.allenty.io` (pro) | `sqa.oci.allenty.io` |
| Load Balancer | `gateway-basa-{env}-lb` | `gateway-basa-sqa-lb` |
| Object Storage bucket | `revenu-platform-tf-state-oci` (único, prefixo por env no path) | — |

## OpenShift — namespaces, labels, annotations

| Recurso | Padrão | Exemplo |
|---|---|---|
| Namespace | `gateway-{env}` (sem prefixo `basa` — o cluster já é dedicado) | `gateway-sqa` |
| Cluster name | `gateway-basa-{env}-ocp` | `gateway-basa-sqa-ocp` |
| Route host | `gateway.{env}.oci.allenty.io` (sqa/uat) · `gateway.allenty.io` (pro) | — |
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
revenu-platform.env = {sqa|uat|pro}
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
| Helm release | `gateway` (namespace isola ambientes) |
| Dockerfile | `docker/Dockerfile.ubi9` |
| GH Actions workflows | `.github/workflows/{ci,cd-sqa,cd-uat,cd-pro,compliance}-oci.yml` |

## Branches e triggers

| Evento | Branch / Ref | Workflow |
|---|---|---|
| Validação | qualquer PR | `ci-oci.yml` |
| sqa deploy | push em `develop` | `cd-sqa-oci.yml` |
| uat deploy | push em `staging` | `cd-uat-oci.yml` |
| pro deploy | tag `v*.*.*` ou `workflow_dispatch` | `cd-pro-oci.yml` |
| Compliance | push/PR em `main`/`develop`/`staging` | `compliance-oci.yml` |

## Secrets GitHub (nomes fixos)

| Nome | Uso |
|---|---|
| `OCI_OIDC_PROVIDER_URL_SQA` / `_UAT` / `_PRO` | URL do IdP federado OCI |
| `OCI_TENANCY_OCID` | OCID do tenancy |
| `OCI_USER_OCID_CI` | OCID do usuário CI (OIDC federated) |
| `OCI_REGION_SQA` / `_UAT` / `_PRO` | ex: `sa-saopaulo-1` |
| `OCIR_REPO_SQA` / `_UAT` / `_PRO` | ex: `gru.ocir.io/tenancy/gateway-basa-sqa` |
| `OCP_CLUSTER_API_SQA` / `_UAT` / `_PRO` | endpoint da API do cluster OpenShift |
| `OCP_SA_TOKEN_SQA` / `_UAT` / `_PRO` | token curto do ServiceAccount CI (ou via OIDC exchange) |
| `SLACK_WEBHOOK_URL` | já existente — reutiliza |

## Regras gerais

1. **Sempre kebab-case** em nomes de recurso cloud; **camelCase** só em JSON/YAML onde já é padrão do provedor.
2. **Nunca** incluir segredos no nome.
3. **env sempre explícito** (`sqa`/`uat`/`pro`) — proibido uso de abreviações como `production` ou `stg`.
4. **Prefixo `gateway-basa-`** em recursos OCI é obrigatório e protege contra colisão com outros workloads no mesmo tenancy/compartimento.
5. **ISO 27001 tag `iso27001=true`** obrigatória em todo recurso auditável (controle A.5.12 — Classification of information).

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
