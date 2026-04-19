# Module — VCN

**Arquiteto Principal:** Gustavo Armoa

## Objetivo

Criar a rede virtual (VCN) para o cluster OpenShift, com subnets por papel
(app/lb/bastion), NSGs granulares, route tables, Internet Gateway e
NAT Gateway.

## Recursos OCI envolvidos

| Componente | Tipo OCI |
|---|---|
| Rede virtual | `oci_core_vcn` |
| Sub-redes | `oci_core_subnet` |
| NAT egress | `oci_core_nat_gateway` |
| Firewall | `oci_core_network_security_group` + rules |
| Pod CIDR | `pod_cidr` no install-config OpenShift (não subnet) |
| Service CIDR | `service_cidr` no install-config OpenShift (não subnet) |
| Flow logs | `oci_logging_log` + VCN flow log subscription |

## Inputs

```hcl
variable "compartment_id"   { type = string }
variable "environment"      { type = string }                    # sqa|uat|pro
variable "region"           { type = string }                    # ex: sa-saopaulo-1
variable "vcn_cidr"         { type = string, default = "10.40.0.0/16" }
variable "subnet_app_cidr"  { type = string, default = "10.40.0.0/20" }   # /20 → 4k IPs
variable "subnet_lb_cidr"   { type = string, default = "10.40.16.0/24" }
variable "subnet_bastion_cidr" { type = string, default = "10.40.17.0/28" }
variable "pod_cidr"         { type = string, default = "10.128.0.0/14" }  # usado em install-config OCP
variable "service_cidr"     { type = string, default = "172.30.0.0/16" }
variable "defined_tags"     { type = map(string) }
variable "freeform_tags"    { type = map(string), default = {} }
variable "allowed_api_cidrs" { type = list(string) }             # IPs que acessam API OCP
```

## Recursos

| Nome TF | Tipo OCI | Quantidade |
|---|---|---|
| `vcn` | `oci_core_vcn` | 1 (`gateway-basa-{env}-vcn`) |
| `igw` | `oci_core_internet_gateway` | 1 |
| `nat` | `oci_core_nat_gateway` | 1 |
| `srvc_gw` | `oci_core_service_gateway` | 1 (acesso a Object Storage sem internet) |
| `rt_public` | `oci_core_route_table` | 1 (tráfego → IGW) |
| `rt_private` | `oci_core_route_table` | 1 (tráfego → NAT + service-gw) |
| `subnet_app` | `oci_core_subnet` | 1 (private, para nodes OpenShift) |
| `subnet_lb` | `oci_core_subnet` | 1 (public, para LoadBalancer) |
| `subnet_bastion` | `oci_core_subnet` | 1 (public, para bastion service) |
| `nsg_api` | `oci_core_network_security_group` | 1 (API OCP — 6443) |
| `nsg_lb` | `oci_core_network_security_group` | 1 (LB público — 80/443) |
| `nsg_nodes` | `oci_core_network_security_group` | 1 (nodes OCP — intra-cluster + SSH via bastion) |
| `nsg_bastion` | `oci_core_network_security_group` | 1 (bastion — SSH entrada) |
| `flow_log` | `oci_logging_log` | 1 (VCN flow logs para Log Group de security) |

## NSG rules (resumo)

### `nsg_nodes`
- Ingress: intra-VCN TCP all, SSH (22) apenas de `nsg_bastion`, Kubelet (10250) apenas intra-VCN.
- Egress: all (via NAT).

### `nsg_api`
- Ingress: TCP 6443 de `var.allowed_api_cidrs` + `nsg_bastion`.
- Egress: all.

### `nsg_lb`
- Ingress: TCP 80 / 443 de 0.0.0.0/0.
- Egress: TCP 8080 → `nsg_nodes`.

### `nsg_bastion`
- Ingress: TCP 22 apenas de `var.allowed_bastion_cidrs` (idealmente IAP-like via OCI Bastion service, sem IP público direto).
- Egress: TCP 22 → `nsg_nodes`, TCP 6443 → `nsg_api`.

## Outputs

```hcl
output "vcn_id"               { value = oci_core_vcn.vcn.id }
output "subnet_app_id"        { value = oci_core_subnet.subnet_app.id }
output "subnet_lb_id"         { value = oci_core_subnet.subnet_lb.id }
output "subnet_bastion_id"    { value = oci_core_subnet.subnet_bastion.id }
output "nsg_nodes_id"         { value = oci_core_network_security_group.nsg_nodes.id }
output "nsg_api_id"           { value = oci_core_network_security_group.nsg_api.id }
output "nsg_lb_id"            { value = oci_core_network_security_group.nsg_lb.id }
output "nsg_bastion_id"       { value = oci_core_network_security_group.nsg_bastion.id }
output "pod_cidr"             { value = var.pod_cidr }
output "service_cidr"         { value = var.service_cidr }
```

## Flow logs

OCI Logging subscribe nos flow logs da subnet `subnet_app` para capturar
tráfego dos nodes. Log Group: `gateway-basa-{env}-vcn-flowlogs`.
Retention: 90 dias.

Destino: opcionalmente shipar para OCI Object Storage via Service Connector
(fora deste módulo; ver `module-monitoring.md`).

## Decisões de design

1. **Subnets regionais vs zonais** — OpenShift IPI recomenda **subnets
   regionais** (uma subnet por ADs). Usar `availability_domain = null`.
2. **Public vs private subnets** — App em private (nodes OCP não têm IP
   público); LB e bastion em public.
3. **Service gateway** — sempre presente, permite pull de imagem OCIR sem
   passar pela NAT (custo + latência).
4. **Sem VPN gateway na v1** — acesso administrativo via Bastion service
   (ADR futuro se precisar peering com rede corporativa).
5. **CIDR `10.40.0.0/16`** reservado para o track Basa (`10.40-10.49`),
   evitando colisão com quaisquer redes privadas corporativas
   pré-existentes.

## Controles ISO 27001

- A.8.20 — Networks security (NSG granular, subnets privadas).
- A.8.22 — Segregation of networks (subnets por papel).
- A.8.16 — Monitoring activities (flow logs).

## Checklist pronto-para-código

- [ ] `modules/vcn/main.tf` com todos os recursos listados.
- [ ] `modules/vcn/variables.tf` + `outputs.tf`.
- [ ] `terraform plan` idempotente.
- [ ] NSG rules testadas com OCI Network Path Analyzer (pós-apply).
- [ ] Flow logs ativos e visíveis em OCI Logging.
- [ ] CIDR não colide com redes privadas corporativas existentes.

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
