# Variables & Tags

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
