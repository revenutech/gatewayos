# Email — Entrega do Runbook Basa ao Banco da Amazônia

**Arquiteto Principal:** Gustavo Armoa

> **Trilha de auditoria.** Este arquivo registra o e-mail formal de
> entrega do runbook de referência `gateway/.base/basa/` ao Banco da
> Amazônia (BASA), com delimitação explícita de responsabilidade entre
> Corebanx / Revenu Platform e a instituição financeira.

## Metadados

| Campo | Valor |
|---|---|
| **Remetente** | Gustavo Armoa — Arquiteto Principal · Corebanx / Revenu Platform · `ola@revenu.com.br` |
| **Destinatários** | [a preencher: Arquitetura / Infraestrutura / Segurança / Comitê de SI do BASA] |
| **CC** | [a preencher: stakeholders internos Corebanx] |
| **Data de envio** | [a preencher no momento do disparo] |
| **Canal** | E-mail corporativo |
| **Assunto** | Entrega do runbook de referência Basa (OCI / OpenShift / Red Hat) — Gateway KrakenD · delimitação de escopo |
| **Anexos** | Nenhum — conteúdo versionado em `github.com:revenutech/gateway.git` · pasta `gateway/.base/basa/` |

## Corpo do e-mail

---

Prezados,

A Corebanx / Revenu Platform, através de sua equipe de arquitetura,
concluiu a elaboração e versionou no repositório do Gateway a pasta
documental **`gateway/.base/basa/`**, contendo o **runbook de
referência** para um eventual deploy do Gateway (KrakenD CE 2.9.4) sobre
a stack **Oracle Cloud Infrastructure (OCI) + Red Hat OpenShift
Container Platform (OCP) + Red Hat UBI**.

### Natureza e escopo da entrega

O conteúdo entregue é um **plano documental estruturado em 9 fases**
(00 a 08), totalizando 66 arquivos markdown:

| Fase | Foco |
|---|---|
| **00 — Foundation** | Escopo, ADRs (001..004), stack reference, plano macro dos 3 envs (sqa / uat / pro), naming conventions |
| **01 — Docker UBI** | Dockerfile UBI9-minimal, build KrakenD CE, FIPS readiness, Red Hat Container Certification |
| **02 — IaC Terraform OCI** | Módulos (VCN, OCP, OCIR, Vault, DNS, Bastion, Monitoring), backend state, variables & tags |
| **03 — Kubernetes / OpenShift** | Helm chart, Route, SCC, NetworkPolicy OVN-K, ServiceMonitor, HPA, PDB, values por env |
| **04 — Observabilidade** | Prometheus Operator, Grafana Operator, Red Hat OTel Operator, OpenShift Logging (Loki), bridge OCI Monitoring/Logging |
| **05 — Security & Supply Chain** | Cosign keyless (GH OIDC), SBOM CycloneDX, Trivy, Red Hat ACS (opcional), FIPS, secrets via OCI Vault + ESO |
| **06 — CI/CD GitHub Actions** | OIDC Federation OCI, `ci-oci`, `cd-sqa-oci`, `cd-uat-oci`, `cd-pro-oci`, `compliance-oci`, rollback strategy |
| **07 — ISO 27001** | Controls matrix (93 controles Annex A), SoA, risk register, evidence mapping |
| **08 — Runbooks** | Bootstrap first apply, TLS on OpenShift, rollback manual, DR cross-region, incident response |

Todos os 66 arquivos contêm:

- **Autoria**: "Arquiteto Principal: Gustavo Armoa" (Corebanx).
- **Disclaimer integral de recomendação base** ao final do documento,
  com as condições detalhadas abaixo.

### Delimitação explícita de responsabilidade

Registramos, neste e-mail e no disclaimer presente em cada arquivo:

1. **A Corebanx / Revenu Platform NÃO é responsável pela operação
   DevSecOps do Gateway KrakenD no ambiente do Banco da Amazônia.**
   Este runbook foi produzido com o único objetivo de **contribuir com
   boas práticas de mercado** e fornecer um ponto de partida acelerado
   à equipe do banco.

2. O material é uma **recomendação técnica de referência** e **não
   constitui garantia** de:
   - segurança cibernética,
   - conformidade regulatória (BACEN, LGPD, auditorias externas),
   - funcionamento em produção.

3. A **implementação efetiva deve ser conduzida por uma equipe
   DevSecOps especializada** com experiência comprovada em:
   - Oracle Cloud Infrastructure (OCI) — IAM, networking, Vault, OCIR,
     observability.
   - Red Hat OpenShift Container Platform (operação self-managed, SCC,
     Operators, upgrades).
   - Red Hat Enterprise Linux / UBI — hardening, FIPS mode, supply
     chain de imagens.

4. A **governança de segurança da informação do Banco da Amazônia**
   permanece sob responsabilidade exclusiva da instituição e deve
   observar, no mínimo:
   - **ISO/IEC 27001:2022** (requisitos ISMS), **27002:2022** (controles
     Annex A), **27003** (implementação), **27004** (monitoramento e
     métricas), **27005** (gestão de risco).
   - **Resoluções BACEN** aplicáveis (em especial a **Resolução nº
     4.893/2021** — Política de Segurança Cibernética).
   - **LGPD** (Lei 13.709/2018).
   - Boas práticas complementares: NIST CSF, CIS Benchmarks, OWASP Top
     10 / ASVS, SANS Critical Controls.

5. **O Banco da Amazônia é a autoridade final** sobre adequação,
   aprovação, implementação e operação de qualquer controle descrito.
   Este documento **não substitui** parecer jurídico, auditoria
   independente, avaliação formal de risco nem aprovação do Comitê de
   Segurança da Informação do banco.

### Próximos passos sugeridos

1. **Revisão técnica** do material pelas equipes de Arquitetura,
   Infraestrutura e Segurança do banco.
2. **Aprovação ou rejeição formal** do material como base de referência.
3. **Definição da equipe DevSecOps** interna ou terceirizada que
   assumirá a implementação.
4. **Avaliação de custo e cronograma** a partir do plano macro em
   `00-foundation/environments-plan.md` (marcos M1..M6).

Estamos à disposição para clarificações, aprofundamento técnico ou
ajustes editoriais sobre qualquer ponto do runbook.

Atenciosamente,

**Gustavo Armoa**
Arquiteto Principal — Corebanx / Revenu Platform
`ola@revenu.com.br`

---

**Referências no repositório:**

- Repo: `github.com:revenutech/gateway.git` · branch `main`
- Pasta: `gateway/.base/basa/`
- Índice principal: `gateway/.base/basa/index.md`
- Plano macro dos ambientes: `gateway/.base/basa/00-foundation/environments-plan.md`
- Commits de referência: `902379d` (refactor Basa, rename sqa/uat/pro),
  `8bf26e6` (atribuição + disclaimer)

---

## Checklist de envio

- [ ] Lista de destinatários confirmada com stakeholder Corebanx.
- [ ] CC internos Corebanx definido (Platform Owner, Legal, Comercial).
- [ ] Assunto final revisado.
- [ ] Link do repositório validado (acesso BASA às referências).
- [ ] Data de envio preenchida neste arquivo após disparo.
- [ ] Confirmação de recebimento registrada (thread de e-mail ou ticket).

## Changelog

- 2026-04-19 — v1 inicial, gerado como trilha de auditoria.

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
