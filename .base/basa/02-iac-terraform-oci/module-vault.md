# Module — Vault (KMS + Secrets)

## Objetivo

Provisionar **OCI Vault** + **Master Encryption Keys** + (opcional) **Secrets**
para criptografia de boot volumes, dados em repouso em Object Storage, e
armazenamento de credenciais consumidas pelo Gateway (ex: pull secrets,
JWKS overrides em dev). Equivalente ao módulo `kms` do track GCP.

## Equivalência GCP ↔ Basa

| GCP | OCI |
|---|---|
| `google_kms_key_ring` | `oci_kms_vault` |
| `google_kms_crypto_key` | `oci_kms_key` (dentro do vault) |
| HSM mode (`protection_level = HSM`) | `protection_mode = HSM` (FIPS 140-2 L3) |
| Rotation period | `key_shape.algorithm` + rotation via API/console |
| Secret Manager (`google_secret_manager_secret`) | `oci_vault_secret` |
| CSI Secret Store Driver + WIF | External Secrets Operator + OCI provider |

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
variable "ci_dynamic_group_id"  { type = string }                      # para policy de gestão de secrets em envs não-prod
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
| dev | SOFTWARE | custo menor, não contém dados reais |
| staging | HSM | paridade com prod para testes realistas |
| prod | HSM | FIPS 140-2 L3, exigência A.8.24 |

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
2. **HSM em prod+staging** — custo baixo (~$8/mês por key HSM) e forte
   evidência A.8.24.
3. **Secrets manualmente populados** — TF referencia, operador enche via
   runbook. Não commitar secrets no state.
4. **`prevent_destroy = true`** em `vault`, `key_app` — evita `terraform
   destroy` acidental.
5. **Deletion protection** — OCI Vault tem "pending deletion period" de
   7–30 dias (configurável). Usar 30 dias em prod.

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
- [ ] CI dynamic group pode ler secrets de `gateway-basa-{env}-vault` (exceto prod).
- [ ] Boot volume encryption validada (detalhe no `oci compute instance get`).
