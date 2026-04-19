# Variables & Tags

**Arquiteto Principal:** Gustavo Armoa

## Objetivo

Padronizar inputs Terraform (variáveis root) e tags aplicadas a todo
recurso, garantindo governança, cost-tracking e evidência ISO 27001.

## Variables root (em cada `environments/{env}/main.tf`)

```hcl
variable "tenancy_ocid"          { type = string }
variable "region"                { type = string }                 # sa-saopaulo-1
variable "compartment_ocid"      { type = string }                 # gateway-basa-{env}
variable "environment"           { type = string }                 # sqa|uat|pro
variable "base_domain"           { type = string }                 # oci.allenty.io (ou subzone)
variable "pull_secret"           { type = string, sensitive = true }  # Red Hat pull secret (vault)
variable "ssh_pub_key"           { type = string }
variable "allowed_api_cidrs"     { type = list(string) }
variable "allowed_bastion_cidrs" { type = list(string) }
variable "notification_email"    { type = string }
```

**Nunca hardcodar OCIDs** em `main.tf` — sempre via variável lida de
`.tfvars` ou env var.

## Defined tags — namespace `revenu-platform`

Criar **uma vez** no tenancy (fora dos módulos de env):

```hcl
resource "oci_identity_tag_namespace" "revenu_platform" {
  compartment_id = var.tenancy_ocid
  name           = "revenu-platform"
  description    = "Revenu Platform — governance tags"
  is_retired     = false
}
```

Tags dentro do namespace:

| Tag | Valores válidos | Obrigatória? |
|---|---|---|
| `app` | `gateway`, `ledgeros`, `paymentos`, etc. | ✅ |
| `track` | `basa` | ✅ |
| `env` | `sqa`, `uat`, `pro` | ✅ |
| `managed-by` | `terraform`, `manual`, `operator` | ✅ |
| `iso27001` | `true`, `false` | ✅ |
| `owner` | `platform-team`, `sre`, `security` | ✅ |
| `cost-center` | `platform`, `engineering`, `shared` | ✅ |
| `data-classification` | `public`, `internal`, `confidential`, `restricted` | opcional (app-specific) |
| `backup-policy` | `daily-7d`, `weekly-4w`, `none` | opcional |

Valores restritos via `oci_identity_tag_default` ou validação manual.

## Freeform tags

Uso liberado para debugging / experiments:

```
created-by = "alice@revenu.com.br"
ticket = "GATE-1234"
temporary = "true"
```

**Não usar freeform tags para billing ou compliance** — apenas defined
tags servem.

## Como aplicar em módulos

Cada módulo aceita:

```hcl
variable "defined_tags"  { type = map(string) }
variable "freeform_tags" { type = map(string), default = {} }
```

No consumer (env main.tf):

```hcl
locals {
  defined_tags = {
    "revenu-platform.app"         = "gateway"
    "revenu-platform.track"       = "basa"
    "revenu-platform.env"         = var.environment
    "revenu-platform.managed-by"  = "terraform"
    "revenu-platform.iso27001"    = "true"
    "revenu-platform.owner"       = "platform-team"
    "revenu-platform.cost-center" = "platform"
  }
}

module "vcn" {
  source        = "../../modules/vcn"
  defined_tags  = local.defined_tags
  # ...
}
```

Dentro do módulo:

```hcl
resource "oci_core_vcn" "vcn" {
  # ...
  defined_tags  = var.defined_tags
  freeform_tags = var.freeform_tags
}
```

## Validação de tags

- **Policy tenant-level:** bloqueia criação de recurso sem `revenu-platform.env`.
  ```
  Allow group {any} to manage all-resources in tenancy where all {request.tagged-values.*contains*("revenu-platform.env")}
  ```
  (sintaxe exata depende da versão do OCI IAM — validar em ambiente de
  testes).
- **OCI Tag Defaults:** auto-preenchem tags em recursos novos se não
  especificadas.
- **Compliance job em CI (Fase 06):** consulta recursos sem tag
  obrigatória e reporta.

## Cost tracking

Tag `cost-center` alimenta OCI Cost Analysis. Report mensal automático
(Service Connector Hub → Object Storage → dashboard).

## Convenções de nomenclatura variáveis

- `snake_case`.
- Sufixo `_ocid` para todo OCID.
- Sufixo `_id` quando genérico (ex: `subnet_id`).
- Sufixo `_cidr` para CIDRs.
- Prefixo `enable_` para booleanas de feature flag.
- Sempre `type` e `description`.
- `sensitive = true` em qualquer variável com secret.

## Exemplo `.tfvars` sqa

```hcl
# environments/sqa/sqa.tfvars — NÃO COMMITAR valores sensitive
tenancy_ocid          = "ocid1.tenancy.oc1..abc"
region                = "sa-saopaulo-1"
compartment_ocid      = "ocid1.compartment.oc1..xyz"
environment           = "sqa"
base_domain           = "sqa.oci.allenty.io"
allowed_api_cidrs     = ["186.xxx.xxx.0/24", "203.xxx.xxx.0/24"]
allowed_bastion_cidrs = ["186.xxx.xxx.0/24"]
notification_email    = "sqa-oncall@revenu.com.br"
ssh_pub_key           = "ssh-ed25519 AAAA..."
# pull_secret lido de env var ou vault, não de tfvars
```

## Checklist pronto-para-código

- [ ] Namespace `revenu-platform` criado no tenancy.
- [ ] Todas as 7 tags obrigatórias aplicadas em 100% dos recursos.
- [ ] Policy tenant-level bloqueia recursos sem tag.
- [ ] `.tfvars` por env no repo (sem valores sensitive).
- [ ] Cost analysis por tag funciona em OCI Console.
- [ ] Compliance check em CI reporta gaps.

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
