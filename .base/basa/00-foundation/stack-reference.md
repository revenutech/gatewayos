# Stack Reference — OCI / OpenShift / Red Hat

**Arquiteto Principal:** Gustavo Armoa

Mapa de referência, camada a camada, das tecnologias usadas pelo track Basa.
Serve de índice rápido para localizar o ativo correto ao desenhar IaC,
Helm, observabilidade e compliance.

## 1. Rede

| Aspecto | Tecnologia |
|---|---|
| Rede virtual | OCI VCN `gateway-{env}-vcn` |
| Sub-redes | Subnets por AD + route tables |
| Firewall | Network Security Groups (NSG) + Security Lists |
| NAT egress | NAT Gateway |
| Peering | Local/Remote Peering Gateway |
| DNS privado | OCI DNS (private views) |

## 2. Compute / Orquestração

| Aspecto | Tecnologia |
|---|---|
| Cluster K8s | OpenShift on OCI (self-managed, HA control plane) |
| Versão | OCP stable channel (ex. 4.16) |
| Node pool | OpenShift MachineSet + Shape OCI (ex. `VM.Standard.E4.Flex`) |
| Autoscaler | OpenShift Machine Autoscaler (MAO) + Cluster Autoscaler operator |
| Release channel | stable-4.x / fast-4.x |
| Admission policy | Sigstore policy-controller ou ACS admission |

## 3. Container Registry

| Aspecto | Tecnologia |
|---|---|
| Registry | OCI Container Registry (OCIR) regional |
| Imutabilidade tag | Retention rules + image signing policy |
| Retenção | Retention policy por repo |
| Scan | Vulnerability scanning nativo OCIR + Trivy externo |
| Auth pull | Image Pull Secret (token OCIR) ou Dynamic Group + Instance Principal |

## 4. Secrets / KMS

| Aspecto | Tecnologia |
|---|---|
| KMS | OCI Vault + Master Encryption Key |
| Secret store | OCI Vault Secrets |
| Consumo em K8s | External Secrets Operator (OCI provider) **ou** Secrets Store CSI + OCI provider |
| HSM | OCI Vault HSM protection mode (FIPS 140-2 L3) |

## 5. DNS & TLS

| Aspecto | Tecnologia |
|---|---|
| Zona DNS | OCI DNS público |
| Delegação | Subdomain delegada para OCI DNS (ex: `oci.allenty.io`) |
| TLS público | cert-manager + Let's Encrypt (DNS01 via OCI DNS) |
| TLS interno | OpenShift service-ca (CA interna, rotaciona) |
| Redirect HTTP→HTTPS | OpenShift Route `insecureEdgeTerminationPolicy: Redirect` |

## 6. Ingress / Exposição

| Aspecto | Tecnologia |
|---|---|
| Ingress | OpenShift Route (HAProxy) |
| LB externo | OCI Load Balancer (Flexible) |
| Target | Service + Route |
| WAF | OCI WAF ou ACS (opcional) |

## 7. Observabilidade

| Aspecto | Tecnologia |
|---|---|
| Métricas | OpenShift Monitoring (Prometheus Operator) + OCI Monitoring (bridge via OTel) |
| Logs | OpenShift Logging (Loki) + OCI Logging (via OTel exporter) |
| Tracing | Red Hat distributed tracing (Tempo / Jaeger) via OTel |
| Alerting | Alertmanager (OpenShift) + OCI Notifications |
| Dashboards | Grafana Operator no OpenShift |

## 8. Imagem base

| Aspecto | Tecnologia |
|---|---|
| Base Docker | UBI9-minimal + build KrakenD CE from source |
| User non-root | `USER 1001` (convenção OpenShift random UID) |
| FIPS | UBI9 + RHCOS em FIPS mode (opcional) |
| Cert | Red Hat Container Certification (labels + license) |

## 9. IAM / Auth para CI/CD

| Aspecto | Tecnologia |
|---|---|
| Auth de workflow | OCI OIDC Federation (GitHub → Domain Identity Provider) |
| Identity K8s | OCI Instance Principal / Resource Principal + RoleBinding |
| Keys estáticas | Proibido (apenas OIDC) |

## 10. Supply Chain

| Aspecto | Tecnologia |
|---|---|
| Assinatura | Cosign keyless (GH OIDC) + opcional Red Hat Trusted Artifact Signer |
| SBOM | CycloneDX via Trivy |
| Scan | Trivy + opcional Red Hat ACS |
| Policy / admission | Sigstore policy-controller ou ACS admission controller |
| Provenance SLSA | SLSA Level 3 via build isolado + OIDC |

## 11. CI/CD

| Aspecto | Tecnologia |
|---|---|
| Orquestrador | GitHub Actions |
| Workflows | `ci-oci.yml`, `cd-sqa-oci.yml`, `cd-uat-oci.yml`, `cd-pro-oci.yml`, `compliance-oci.yml` |
| Approval gate | `environment: pro-oci` |
| Rollback | `helm rollback gateway 0` |

## 12. Estado Terraform

| Aspecto | Tecnologia |
|---|---|
| Backend | OCI Object Storage bucket `revenu-platform-tf-state-oci` |
| Locking | Object Storage + OCI-native lock (`use_lockfile = true`, TF ≥ 1.10) |
| Prefixo | `gateway-basa/{env}` |

## 13. ISO 27001

| Aspecto | Tecnologia |
|---|---|
| ISMS Scope | OpenShift + OCIR + OCI Vault (documentado em 07) |
| Controls Matrix | 93 controles com evidências OCI/OpenShift |
| Risk register | Riscos B-R01..R04 + específicos da Fase 07 |
| Annex A.8.31 | Separação de envs OCI (compartments) |

## Gaps reconhecidos

- **Zero-trust / service mesh** — fora do escopo v1.
- **Backup de etcd** — OpenShift fornece nativo (`cluster-backup.sh`); runbook em 08.

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
