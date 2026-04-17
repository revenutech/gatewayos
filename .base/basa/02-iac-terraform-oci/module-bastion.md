# Module — Bastion

## Objetivo

Prover acesso administrativo seguro ao control plane OpenShift (API 6443)
e nodes via **OCI Bastion service** (zero-trust, sessão SSH temporária,
MFA via OCI IAM). Sem equivalente direto em GCP (que usa IAP Tunnel +
private GKE endpoint); Basa precisa pois OCP API não pode ficar 100%
pública.

## Equivalência GCP ↔ Basa

| GCP | OCI |
|---|---|
| IAP TCP tunneling (`gcloud compute ssh --tunnel-through-iap`) | OCI Bastion service (sessions SSH / port-forward) |
| Cloud Shell com gcloud já autenticado | OCI Cloud Shell ou workstation local com OCI CLI |
| Master authorized networks | Bastion allowlist + NSG rules |

## Inputs

```hcl
variable "compartment_id"          { type = string }
variable "environment"             { type = string }
variable "vcn_id"                  { type = string }
variable "subnet_bastion_id"       { type = string }
variable "target_subnet_ids"       { type = list(string) }  # onde o bastion pode abrir sessions
variable "allowed_client_cidrs"    { type = list(string) }  # quem pode conectar (IPs corporativos)
variable "max_session_ttl_seconds" { type = number, default = 10800 }  # 3h
variable "defined_tags"            { type = map(string) }
```

## Recursos

| Nome TF | Tipo OCI | Notas |
|---|---|---|
| `bastion` | `oci_bastion_bastion` | single bastion por env |
| `group_admins` | `oci_identity_group` (referenciado, não criado aqui) | usuários com permissão |
| `policy_bastion_usage` | `oci_identity_policy` | permite `use bastion` + `use bastion-session` |

## Tipos de sessão suportados

1. **Managed SSH** — session temporária conectando a compute instance
   específica via SSH. Usa chave SSH do usuário.
2. **Port forwarding** — tunneling L4 (ex: acesso ao API OCP 6443 via
   forward local).

Para `kubectl` funcionar em cluster privado:

```
oci bastion session create-port-forwarding \
  --bastion-id <bastion-ocid> \
  --target-resource-id <lb-api-ocid> \
  --target-port 6443 \
  --session-ttl 10800
# saída: comando SSH para criar port-forward local
```

Depois: `kubectl --server=https://localhost:6443 ...` via `kubeconfig` já
emitido pelo installer.

## Policy mínima

```
Allow group gateway-platform-admins to use bastion in compartment id <compartment>
Allow group gateway-platform-admins to manage bastion-session in compartment id <compartment>
Allow group gateway-platform-admins to read all-resources in compartment id <compartment>
```

## Outputs

```hcl
output "bastion_ocid"       { value = oci_bastion_bastion.bastion.id }
output "bastion_name"       { value = oci_bastion_bastion.bastion.name }
output "max_ttl"            { value = var.max_session_ttl_seconds }
```

## Decisões de design

1. **OCI Bastion service, não bastion host compute** — sem VM a manter,
   sessions efêmeras (A.8.2).
2. **Allowlist por CIDR corporativo** — refinar para IdP-integrated auth
   em iteração futura.
3. **TTL 3h** — balance entre usabilidade e mínima exposição.
4. **Auditoria nativa** — sessions vão para OCI Audit automaticamente.

## Controles ISO 27001

- A.8.2 — Privileged access rights.
- A.8.5 — Secure authentication.
- A.5.15 — Access control.
- A.8.15 — Logging (audit de sessions).

## Checklist pronto-para-código

- [ ] `modules/bastion/` criado.
- [ ] Runbook em Fase 08 descreve como criar session.
- [ ] Tabela de `allowed_client_cidrs` mantida em Vault (rotacionável).
- [ ] Session audits visíveis em OCI Audit.
