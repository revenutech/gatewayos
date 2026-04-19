# Escopo — Track Basa (OCI / OpenShift / Red Hat)

**Arquiteto Principal:** Gustavo Armoa

## Objetivo

Produzir um plano documental completo para operar o **Gateway (KrakenD CE
2.9.4)** em um ambiente baseado em:

- **Infraestrutura** — Oracle Cloud Infrastructure (OCI).
- **Orquestração** — OpenShift (Red Hat OpenShift Container Platform) rodando
  sobre OCI.
- **Imagem base** — Red Hat Universal Base Image (UBI9-minimal).

O plano deve cobrir todo o ciclo: build → push → deploy → observar → proteger →
auditar → responder a incidente → recuperar.

## Escopo — In

1. **Docker / Imagem** — Dockerfile sobre UBI9, build reprodutível, assinado,
   com SBOM, FIPS-ready, pronto para Red Hat Container Certification.
2. **Infraestrutura (Terraform)** — módulos OCI (VCN, OpenShift, OCIR, Vault,
   DNS, Monitoring, Bastion) e envs sqa/uat/pro.
3. **Kubernetes / OpenShift** — Helm chart com Route, SCC, NetworkPolicy
   OVN-K, ServiceMonitor, HPA, PDB.
4. **Observabilidade** — Prometheus Operator + Grafana Operator + Red Hat OTel
   Operator + OpenShift Logging (Loki).
5. **Segurança & Supply Chain** — Cosign keyless (GH OIDC), SBOM CycloneDX,
   Trivy, opcional Red Hat ACS, FIPS mode, fluxo de secrets via OCI Vault.
6. **CI/CD (GitHub Actions)** — OIDC Federation para OCI, pipelines ci,
   cd-sqa, cd-uat, cd-pro, compliance.
7. **ISO 27001** — mapeamento dos 93 controles Annex A, SoA, risk register,
   evidence mapping.
8. **Runbooks** — bootstrap, TLS, rollback, DR multi-region, resposta a
   incidente.

## Escopo — Out (nesta iteração)

- Federação Keycloak com provedor externo (JWKS continua apontando para
  o Keycloak atual; o track Basa apenas consome).
- Onboarding dos demais módulos backend (LedgerOS, Paymentos, etc.) em OCI —
  foco é apenas Gateway.
- Custos detalhados e contratação comercial de OCI/Red Hat (plano assume que
  licenças e tenancy já existem).

## Premissas

- **OCI tenancy** provisionada e com quotas suficientes para sqa + uat + pro.
- **Licença OpenShift** válida (subscription Red Hat OCP ou CCSP via OCI).
- **GitHub repo** mantém OIDC habilitado.
- **Keycloak** (JWKS) permanece no provedor atual durante todo o plano.
- **Domínios** — `*.allenty.io` continua sob controle (delegação para OCI DNS
  das subdomains usadas pelo track Basa a ser definida na Fase 02).
- **ISO 27001** — ISMS já existente em `.base/docs/isms/` cobre o Gateway;
  este plano produz o capítulo OCI/OpenShift do ISMS.

## Stakeholders

| Papel | Responsabilidade |
|---|---|
| Platform Owner | Aprova escopo e ADRs; prioriza fases. |
| ISO Lead | Valida controles, SoA e risk register. |
| SRE Lead | Valida IaC, observabilidade e runbooks. |
| Security Lead | Valida supply chain, FIPS, ACS, secrets flow. |
| DevEx | Valida pipelines GitHub Actions e DX. |

## Riscos macro (entradas para risk register da Fase 07)

| ID | Risco | Mitigação planejada |
|---|---|---|
| B-R01 | Lock-in de região OCI (capacidade OpenShift limitada em `sa-saopaulo-1`) | ADR de região + plano DR cross-region na Fase 08 |
| B-R02 | Licenciamento UBI — mudanças na política Red Hat | Usar UBI9-minimal (redistribuível); documentar em 01 |
| B-R03 | Cadência de upgrade OpenShift (self-managed control plane) | Runbook de upgrade + janelas em 08 |
| B-R04 | Complexidade OIDC GitHub → OCI (produto mais recente, menos docs) | ADR + documento dedicado em 06 |

## Critérios de sucesso

1. Qualquer engenheiro do time consegue, lendo apenas `.base/basa/`, abrir PRs
   para materializar cada fase sem ambiguidade.
2. Auditoria ISO 27001 consegue, a partir de 07, mapear evidências OCI/OpenShift
   para os 93 controles Annex A.

## Referências

- ISMS: `.base/docs/isms/`.
- Risk methodology: `.base/docs/risk/risk-methodology.md`.
- Controls matrix: `.base/docs/compliance/controls-matrix.md`.

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
