# Module — Vault (KMS + Secrets)

**Arquiteto Principal:** Gustavo Armoa

## Objetivo

Provisionar **OCI Vault** + **Master Encryption Keys** + (opcional) **Secrets**
para criptografia de boot volumes, dados em repouso em Object Storage, e
armazenamento de credenciais consumidas pelo Gateway (ex: pull secrets,
JWKS overrides em sqa).

## Recursos OCI envolvidos

| Finalidade | Tipo OCI |
|---|---|
| Vault (keyring) | `oci_kms_vault` |
| Chave de criptografia | `oci_kms_key` |
| HSM mode | `protection_mode = HSM` (FIPS 140-2 L3) |
| Rotation | via `oci kms management rotate-key-version` |
| Secret store | `oci_vault_secret` |
| Consumo em K8s | External Secrets Operator (OCI provider) |

## Inputs

```hcl
variable "compartment_id"     { type = string }
variable "environment"        { type = string }
variable "vault_type"         { type = string, default = "DEFAULT" }  # ou "VIRTUAL_PRIVATE"
variable "protection_mode"    { type = string, default = "HSM" }      # HSM ou SOFTWARE
variable "key_algorithm"      { type = string, default = "AES" }
variable "key_length"         { type = number, default = 32 }          # 256-bit
variable "rotation_days"      { type = number, default = 90 }          # docs only; rotation é manual/API
variable "defined_tags"       { type = map(string) }
variable "ocp_dynamic_group_id" { type = string }                      # para policy de decrypt
variable "ci_dynamic_group_id"  { type = string }                      # para policy de gestão de secrets em envs não-pro
```

## Recursos

| Nome TF | Tipo OCI | Finalidade |
|---|---|---|
| `vault` | `oci_kms_vault` | `gateway-basa-{env}-vault` |
| `key_app` | `oci_kms_key` | Master Key geral do app (JWT signing refs, etc.) |
| `key_tfstate` | `oci_kms_key` | Criptografia do bucket tfstate |
| `key_backup` | `oci_kms_key` | Para backups futuros (etcd, DB) |
| `secret_pullsecret_rh` | `oci_vault_secret` | Red Hat pull secret (necessário no install) |
| `secret_ocir_push` | `oci_vault_secret` | Token CI para push OCIR (rotacionado) |
| `secret_slack_webhook` | `oci_vault_secret` | (opcional) webhook para alerting |
| `policy_key_usage` | `oci_identity_policy` | Decrypt/encrypt para dynamic groups |

## Protection mode

| Env | Modo | Justificativa |
|---|---|---|
| sqa | SOFTWARE | custo menor, não contém dados reais |
| uat | HSM | paridade com pro para testes realistas |
| pro | HSM | FIPS 140-2 L3, exigência A.8.24 |

## Key rotation

OCI Vault não faz rotation automática. Documentar em runbook (Fase 08):

- **Cadência:** 90 dias para `key_app`, 180 dias para `key_tfstate`, 365
  para `key_backup`.
- **Procedure:** via `oci kms management rotate-key-version`. Versão
  anterior permanece para decriptar históricos.
- **Responsável:** Security Lead (RACI em ISMS).

## IAM policies

```hcl
# policy_key_usage
statements = [
  "Allow dynamic-group ${var.ocp_dynamic_group_id} to use keys in compartment id ${var.compartment_id} where target.key.id = '${oci_kms_key.key_app.id}'",
  "Allow dynamic-group ${var.ci_dynamic_group_id} to use keys in compartment id ${var.compartment_id} where target.key.id = '${oci_kms_key.key_tfstate.id}'",
  "Allow dynamic-group ${var.ocp_dynamic_group_id} to read secrets in compartment id ${var.compartment_id}",
]
```

## Integração com OpenShift

Fluxo secrets (Fase 03 documenta em detalhe):

```
OCI Vault Secret
      ▼
External Secrets Operator (oci provider)
      ▼
Kubernetes Secret (gateway-* no namespace gateway-{env})
      ▼
Deployment consome via envFrom / volumeMount
```

Alternativa: **Secrets Store CSI Driver** com OCI provider. ESO é mais
popular; v1 adota ESO.

## Boot volume encryption

`module-openshift.md` referencia `kms_key_id = output.key_app.id` para
criptografar boot volumes de masters e workers.

## Outputs

```hcl
output "vault_ocid"            { value = oci_kms_vault.vault.id }
output "vault_endpoint"        { value = oci_kms_vault.vault.management_endpoint }
output "key_app_ocid"          { value = oci_kms_key.key_app.id }
output "key_tfstate_ocid"      { value = oci_kms_key.key_tfstate.id }
output "key_backup_ocid"       { value = oci_kms_key.key_backup.id }
output "secret_pullsecret_id"  { value = oci_vault_secret.secret_pullsecret_rh.id, sensitive = true }
```

## Decisões de design

1. **3 chaves separadas** (app/tfstate/backup) — blast radius reduzido se
   uma chave for comprometida.
2. **HSM em pro+uat** — custo baixo (~$8/mês por key HSM) e forte
   evidência A.8.24.
3. **Secrets manualmente populados** — TF referencia, operador enche via
   runbook. Não commitar secrets no state.
4. **`prevent_destroy = true`** em `vault`, `key_app` — evita `terraform
   destroy` acidental.
5. **Deletion protection** — OCI Vault tem "pending deletion period" de
   7–30 dias (configurável). Usar 30 dias em pro.

## Controles ISO 27001

- A.8.24 — Use of cryptography.
- A.5.16 — Identity management (acesso via dynamic groups).
- A.5.17 — Authentication information (secrets fora do código).
- A.8.5 — Secure authentication (JWKS / pull secrets isolados em Vault).

## Checklist pronto-para-código

- [ ] `modules/vault/` completo com 3 keys e variáveis.
- [ ] `prevent_destroy = true` nos recursos críticos.
- [ ] Secrets vazios (ou com placeholder) — populados por runbook pós-apply.
- [ ] OCP dynamic group pode decrypt via ESO.
- [ ] CI dynamic group pode ler secrets de `gateway-basa-{env}-vault` (exceto pro).
- [ ] Boot volume encryption validada (detalhe no `oci compute instance get`).

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
