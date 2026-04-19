# Module — Bastion

**Arquiteto Principal:** Gustavo Armoa

## Objetivo

Prover acesso administrativo seguro ao control plane OpenShift (API 6443)
e nodes via **OCI Bastion service** (zero-trust, sessão SSH temporária,
MFA via OCI IAM). O bastion é necessário porque o API OCP fica privado
(não exposto publicamente).

## Capacidades

| Item | Detalhe |
|---|---|
| Acesso privilegiado | OCI Bastion service (sessions SSH / port-forward) |
| Cliente | OCI Cloud Shell ou workstation local com OCI CLI |
| Controle de acesso | Bastion allowlist + NSG rules |

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
