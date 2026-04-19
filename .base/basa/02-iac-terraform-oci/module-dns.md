# Module — DNS

## Objetivo

Gerenciar zonas e registros DNS públicos para os hostnames do track Basa.

## Recursos OCI envolvidos

| Item | Tipo OCI |
|---|---|
| Zona | `oci_dns_zone` |
| Record set | `oci_dns_rrset` |
| Delegation | Manual — NS records na zona pai `allenty.io` |

## Estratégia de domínios

- Zona raiz `allenty.io` permanece no registrar/provider atual.
- Delegar subzona **`oci.allenty.io`** para OCI DNS (NS records na zona
  pai apontando para OCI).
- Subdomínios por env:
  - **pro** — `gateway.oci.allenty.io`.
  - **uat** — `gateway.uat.oci.allenty.io`.
  - **sqa** — `gateway.sqa.oci.allenty.io`.

## Inputs

```hcl
variable "compartment_id"    { type = string }
variable "environment"       { type = string }
variable "zone_name"         { type = string }                   # oci.allenty.io ou {env}.oci.allenty.io
variable "create_zone"       { type = bool, default = true }     # sqa cria zona subdomain; pro usa zona existente
variable "records"           {
  type = list(object({
    name     = string
    type     = string
    rdata    = string
    ttl      = number
  }))
  default = []
}
variable "defined_tags"      { type = map(string) }
```

## Recursos

| Nome TF | Tipo OCI | Notas |
|---|---|---|
| `zone` | `oci_dns_zone` | criada se `var.create_zone = true` |
| `records` | `oci_dns_rrset` (for_each) | um por entrada em `var.records` |
| `cert_manager_dns_user` | `oci_identity_user` (ou dynamic group) | usado por cert-manager-webhook-oci para DNS01 |
| `policy_dns_updates` | `oci_identity_policy` | permite escrita TXT `_acme-challenge.*` no compartment |

## Registros por env

### sqa

| Nome | Tipo | rdata | TTL | Finalidade |
|---|---|---|---|---|
| `gateway` | A | `<ingress LB IP>` | 60 | Public endpoint |
| `*.gateway` | CNAME | `gateway.sqa.oci.allenty.io` | 60 | Wildcard para rotas OpenShift |
| `api.gateway-basa-sqa-ocp` | A | `<api NLB IP>` | 60 | OCP API (acesso via bastion) |

### uat / pro

Análogo, com hostnames `gateway.uat.oci.allenty.io` e
`gateway.oci.allenty.io`.

## Delegação

**Manual, uma vez**, na zona pai `allenty.io`:

```
oci.allenty.io.        86400   IN  NS  ns1.oracle.com.
oci.allenty.io.        86400   IN  NS  ns2.oracle.com.
oci.allenty.io.        86400   IN  NS  ns3.oracle.com.
oci.allenty.io.        86400   IN  NS  ns4.oracle.com.
```

Documentar em `08-runbooks/bootstrap-first-apply.md`.

## Cert-manager integration

Para DNS01 challenges do Let's Encrypt (ADR-003):

- Criar user `cert-manager-dns` **ou** usar Resource Principal do pod
  cert-manager no OCP.
- Policy `policy_dns_updates` permite:
  ```
  Allow dynamic-group <cert-manager-dg> to manage dns-records in compartment id <compartment> where
    target.zone.name='oci.allenty.io'
    and any { target.record.type='TXT' and target.record.name like '_acme-challenge.%' }
  ```
- cert-manager-webhook-oci usa esta credencial para criar TXT de challenge.

## Outputs

```hcl
output "zone_ocid"           { value = oci_dns_zone.zone.id }
output "zone_nameservers"    { value = oci_dns_zone.zone.nameservers }
output "zone_name"           { value = var.zone_name }
```

## Decisões de design

1. **Subzona por env** — `sqa.oci.allenty.io` isola DNS, facilita GitOps
   e evita interferência cross-env.
2. **Wildcard CNAME** para rotas OpenShift — OCP Router por default usa
   `*.apps.<cluster>.<base_domain>`, e expomos apps via `*.gateway.<env>.oci.allenty.io`.
3. **TTL baixo (60s)** para records de apps — facilita rollback/troca de IP.
4. **TTL alto (3600s)** para records administrativos que não mudam.

## Controles ISO 27001

- A.5.23 — Information security for use of cloud services (DNS hospedado).
- A.8.20 — Networks security.

## Checklist pronto-para-código

- [ ] `modules/dns/` criado com suporte a `for_each` em records.
- [ ] Delegação NS na zona pai feita manualmente e registrada em runbook.
- [ ] cert-manager consegue solucionar DNS01 em sqa.
- [ ] Resolução DNS externa funciona antes de expor o Gateway.
