# Controls Matrix — OCI/OpenShift

**Arquiteto Principal:** Gustavo Armoa

Complementa `.base/docs/compliance/controls-matrix.md`. Para cada
controle Annex A relevante ao track Basa, mostra a **evidência Basa**
(OCI/OpenShift/Red Hat) com comandos, console paths e artefatos.

> Lista ordenada pelos 93 controles Annex A (ISO/IEC 27001:2022).
> Legenda aplicabilidade: ✅ aplica · 🟡 aplica parcialmente · ➖ não aplica.

## A.5 — Organizational controls (37)

| Ctrl | Título | Aplica no Basa? | Evidência Basa |
|---|---|:-:|---|
| A.5.1 | Policies for information security | ✅ | Mesma política ISMS; Fase 00 `scope.md` + ADRs |
| A.5.2 | Information security roles | ✅ | Platform Owner / ISO Lead / SRE Lead / Security Lead (Fase 00 `scope.md`) |
| A.5.3 | Segregation of duties | ✅ | GitHub environment `pro-oci` exige 2 reviewers (Fase 06) |
| A.5.7 | Threat intelligence | ✅ | Red Hat OVAL (Trivy) + CVE feed OCI + KrakenD mailing list (mantido) |
| A.5.8 | Infosec in project management | ✅ | Esta Fase 00..08 é o artefato |
| A.5.12 | Classification of information | ✅ | Defined tag `revenu-platform.data-classification` (Fase 02) |
| A.5.14 | Information transfer | ✅ | TLS edge + service-ca (Fase 03) |
| A.5.15 | Access control | ✅ | OCI IAM + OCP RBAC + SCC (Fase 02/03) |
| A.5.16 | Identity management | ✅ | OCI Identity Domain + OpenShift IdP (mantido) |
| A.5.17 | Authentication information | ✅ | OCI Vault + ESO (Fase 05 `secrets-flow.md`) |
| A.5.18 | Access rights | ✅ | OCI Policies por compartment (Fase 06 `oci-oidc-federation.md`) |
| A.5.19 | Supplier relationships | ✅ | Contratos OCI + Red Hat (fora do repo); catálogo em `evidence-mapping.md` |
| A.5.20 | Infosec in supplier agreements | ✅ | OCI DPA / Red Hat MSA arquivados |
| A.5.21 | Supply chain | ✅ | Cosign + SBOM + SLSA (Fase 05) |
| A.5.22 | Monitoring supplier services | ✅ | OCI Health Dashboard + Red Hat Insights |
| A.5.23 | Use of cloud services | ✅ | ADR-001..004 (Fase 00) |
| A.5.24 | Incident management planning | ✅ | IRP existente + delta em Fase 08 |
| A.5.25 | Assessment of security events | ✅ | Alertmanager user workload (Fase 04) + OCI Monitoring alarms |
| A.5.26 | Response to incidents | ✅ | Rollback strategy (Fase 06) + IRP delta |
| A.5.27 | Learning from incidents | ✅ | RCA obrigatório em 48h (Fase 06 `rollback-strategy.md`) |
| A.5.28 | Collection of evidence | ✅ | `evidence-mapping.md` + compliance-oci.yml daily report (7 anos retention) |
| A.5.29 | Infosec during disruption | ✅ | 3 masters OCP + workers multi-AD (Fase 02) + BCP |
| A.5.30 | ICT readiness for BC | ✅ | DR runbook cross-region (Fase 08) |
| A.5.31 | Legal/regulatory compliance | ✅ | Rekor transparency log (Fase 05) |
| A.5.32 | Intellectual property | ✅ | `LICENSE` no repo + `/licenses/` na imagem |
| A.5.33 | Protection of records | ✅ | Object Storage archive 7 anos (Fase 02/04) |
| A.5.34 | Privacy / PII | ✅ | Sem PII em labels Prometheus (Fase 03/04) |
| A.5.35 | Independent review | ✅ | compliance-oci.yml daily (Fase 06) |
| A.5.36 | Compliance with policies | ✅ | Trivy + audit.sh + compliance-oci.yml (Fase 06) |
| A.5.37 | Documented operating procedures | ✅ | Runbooks Fase 08 |

## A.6 — People controls (8)

| Ctrl | Título | Aplica? | Evidência Basa |
|---|---|:-:|---|
| A.6.1 | Screening | ✅ | HR process — inalterado |
| A.6.2 | Terms and conditions | ✅ | Employment agreement — inalterado |
| A.6.3 | Awareness, training | ✅ | Treinamento OCI + OCP no onboarding (runbook Fase 08) |
| A.6.4 | Disciplinary process | ✅ | HR process — inalterado |
| A.6.5 | Post-employment | ✅ | OCI user/group removal on offboarding |
| A.6.6 | Confidentiality | ✅ | NDA — inalterado |
| A.6.7 | Remote working | ✅ | OCI Bastion + MFA (Fase 02/06) |
| A.6.8 | Event reporting | ✅ | #gateway-alerts Slack + OCI Audit |

## A.7 — Physical controls (14)

Controles majoritariamente delegados ao provider (OCI + Red Hat).
Evidência: **certificações do fornecedor** (OCI SOC 2, ISO 27001;
Red Hat OpenShift ISO 27001).

| Ctrl | Aplica? | Nota |
|---|:-:|---|
| A.7.1 | ✅ | OCI data center — certificações no `evidence-mapping.md` |
| A.7.2 | ✅ | idem |
| A.7.3 | ✅ | idem |
| A.7.4 | ✅ | idem |
| A.7.5 | ✅ | idem |
| A.7.6 | ✅ | idem |
| A.7.7 | ✅ | Clear desk — HR |
| A.7.8 | ✅ | Workstations — HR |
| A.7.9 | ➖ | Off-premises — laptops não armazenam chaves de produção |
| A.7.10 | ✅ | Storage media — OCI gerencia |
| A.7.11 | ✅ | Supporting utilities — OCI |
| A.7.12 | ✅ | Cabling — OCI |
| A.7.13 | ✅ | Maintenance — OCI |
| A.7.14 | ✅ | Secure disposal — OCI Vault delete + Object Storage retention |

## A.8 — Technological controls (34)

Core para o Basa. Evidências diretas.

| Ctrl | Título | Aplica? | Evidência Basa |
|---|---|:-:|---|
| A.8.1 | User endpoint devices | ✅ | Bastion + VPN corp — inalterado |
| A.8.2 | Privileged access rights | ✅ | OCI Dynamic Groups + OCP RBAC + SCC restricted-v2 (Fase 02/03) |
| A.8.3 | Information access restriction | ✅ | NetworkPolicy OVN-K + EgressFirewall (Fase 03) |
| A.8.4 | Access to source code | ✅ | GitHub branch protection + CODEOWNERS (mantido) |
| A.8.5 | Secure authentication | ✅ | JWT RS256 (mantido) + OIDC Federation sem keys (Fase 06) |
| A.8.6 | Capacity management | ✅ | HPA + Machine Autoscaler (Fase 03) |
| A.8.7 | Protection against malware | 🟡 | Trivy scan (v1); ACS runtime detection em plano v2 (Fase 05) |
| A.8.8 | Vulnerability management | ✅ | Trivy em CI + Red Hat OVAL + `.trivyignore` review trimestral (Fase 05) |
| A.8.9 | Configuration management | ✅ | Helm + Terraform versionados; imagens imutáveis pro OCIR (Fase 02/03) |
| A.8.10 | Information deletion | ✅ | Vault pending-deletion 30d + Object Storage lifecycle |
| A.8.11 | Data masking | ✅ | Lua DLP plugin (mantido) + sem PII em labels (Fase 03/04) |
| A.8.12 | Data leakage prevention | ✅ | Access logs structured + Vector filter (Fase 04) |
| A.8.13 | Backup | ✅ | etcd snapshot OpenShift (Fase 08) + tfstate versioning (Fase 02) |
| A.8.14 | Redundancy | ✅ | 3 masters + workers multi-AD (Fase 02) + PDB `minAvailable:2` (Fase 03) |
| A.8.15 | Logging | ✅ | OpenShift Logging (Loki) + OCI Audit + VCN flow logs (Fase 02/04) |
| A.8.16 | Monitoring activities | ✅ | Prometheus + Grafana Operator + OTel + OCI Monitoring alarms (Fase 02/04) |
| A.8.17 | Clock synchronization | ✅ | NTP RHCOS nativo |
| A.8.18 | Privileged utility programs | ✅ | Bastion service TTL 1h pro (Fase 02) |
| A.8.19 | Installation on operational systems | ✅ | Sigstore policy-controller + immutable tags pro (Fase 05) |
| A.8.20 | Networks security | ✅ | VCN + NSG + NetworkPolicy + HSTS (Fase 02/03) |
| A.8.21 | Security of network services | ✅ | Managed LB + Route + TLS 1.2+ |
| A.8.22 | Segregation of networks | ✅ | Compartments per env + subnets + namespaces + NetPol (Fase 02/03) |
| A.8.23 | Web filtering | ✅ | HSTS + EgressFirewall (Fase 03) |
| A.8.24 | Use of cryptography | ✅ | Vault HSM pro + Cosign + TLS 1.2+ + FIPS-ready (Fase 01/02/05) |
| A.8.25 | Secure development life cycle | ✅ | CI + trivy + review + Cosign sign (Fase 06) |
| A.8.26 | Application security requirements | ✅ | JWT RBAC + rate limit + CEL tenant check (mantido) |
| A.8.27 | Secure system architecture | ✅ | Defense-in-depth (Fase 05 README) |
| A.8.28 | Secure coding | ✅ | Trivy secret-scan + hadolint (Fase 06) |
| A.8.29 | Security testing in development | ✅ | compliance-oci.yml + audit.sh (Fase 06) |
| A.8.30 | Outsourced development | ✅ | KrakenD CE + UBI9 + Red Hat operators (Fase 01) |
| A.8.31 | Separation of environments | ✅ | 3 compartments OCI + 3 clusters OCP + 3 namespaces (Fase 02/03) |
| A.8.32 | Change management | ✅ | Helm atomic + 2 reviewers pro + change ticket (Fase 06) |
| A.8.33 | Test information | ✅ | uat sintético — sem dados reais |
| A.8.34 | Protection during audit | ✅ | Compliance Operator read-only scan |

## Notas de implementação

| Controle | Nota |
|---|---|
| A.8.7 Malware | Trivy CI em v1; ACS runtime detection documentado como próximo passo (Fase 05) |
| A.8.24 Crypto | OCI Vault HSM (FIPS 140-2 L3) em uat + pro; FIPS mode ativável no cluster |
| A.8.13 Backup | etcd OCP backup + tfstate versioning em OCI Object Storage |
| A.8.15 Logging | OpenShift Logging (Loki) + OCI Audit + VCN flow logs |
| A.7 Physical | Delegado à OCI; evidência via certificações Oracle + Red Hat |

## Controles críticos — evidência rápida

| Ctrl | 1-line evidência Basa |
|---|---|
| A.8.2 | `oci iam policy list --compartment-id gateway-basa-pro` |
| A.8.15 | Console OCI → Logging → Log Groups `gateway-basa-pro-*` |
| A.8.24 | Console OCI → Vault → Keys `gateway-basa-pro-key-app` (HSM) |
| A.8.31 | Três compartments + três namespaces separados (`oc get ns gateway-{sqa,uat,pro}`) |
| A.8.32 | GitHub releases + environment `pro-oci` 2 reviewers |
| A.5.21 | `cosign verify ... gateway:v1.0.0@sha256:...` |

## Controles integralmente cobertos pelo operator nativo RH

Compliance Operator gera evidência automática para:
- CIS OpenShift Benchmark — cobre ~A.8.2, A.8.22, A.8.20, A.8.9.
- NIST SP 800-53 — cobre boa parte A.5/A.8.

Relatório automático entra em `evidence-mapping.md` como recorrente.

## Checklist pronto-para-código

- [ ] Controls matrix aprovada por ISO Lead.
- [ ] controls-matrix.md principal atualizado (coluna extra ou link).
- [ ] compliance-oci.yml valida que este arquivo existe (Fase 06).
- [ ] Cada evidência apontando para arquivo/comando concreto.
- [ ] Revisão anual na Management Review (A.9.3).

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
