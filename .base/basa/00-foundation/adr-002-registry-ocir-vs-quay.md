# ADR-002 — Container Registry: OCIR vs Quay.io

**Arquiteto Principal:** Gustavo Armoa

- **Status:** Aceito
- **Data:** 2026-04-17
- **Decisores:** Platform Owner, Security Lead
- **Relacionado:** ADR-004, stack-reference.md §3

## Contexto

O track Basa precisa de um container registry para a imagem do Gateway
assinada, escaneada e com retenção controlada. Duas opções naturais no
ecossistema OCI + Red Hat:

1. **OCI Container Registry (OCIR)** — registry nativo da OCI, regional,
   integrado com IAM OCI, pull via Image Pull Secret ou Instance Principal.
2. **Quay.io (hosted) ou Red Hat Quay (self-hosted)** — registry Red Hat com
   integração nativa a OpenShift, ACS, vulnerability scanning (Clair),
   Cosign, notificações.

## Opções consideradas

| Critério | OCIR | Quay.io (hosted) | Red Hat Quay (self-hosted) |
|---|---|---|---|
| Latência pull da OCI | 🟢 Intra-região | 🟡 Internet | 🟡 depende onde hospedar |
| Custo storage | Pago por GB | Plano grátis + pago | Subscription RH + compute |
| Integração OCP | 🟡 Pull secret manual | 🟢 Nativa | 🟢 Nativa |
| Scan vulnerabilidades | 🟡 básico | 🟢 Clair nativo | 🟢 Clair nativo |
| Cosign signing | 🟢 compatível (OCI standard) | 🟢 compatível | 🟢 compatível |
| Imutabilidade de tag | 🟢 retention rules | 🟢 | 🟢 |
| IAM | OCI IAM | Red Hat SSO | Red Hat SSO |
| Compliance ISO (dados EU/BR) | 🟢 controla região | 🟡 hosted em região RH | 🟢 self-hosted |
| Complexidade operacional | Baixa (gerenciado) | Baixa (SaaS) | Alta (operar Quay) |
| Lock-in | Médio (OCI) | Alto (SaaS RH) | Baixo |

## Decisão

**Adotar OCIR como registry primário** do track Basa.

**Cosign + Trivy** são o controle de supply chain primário, rodando sobre
OCIR — o registry em si fica neutro.

**Red Hat Quay** fica documentado como opção para um segundo momento, caso
exijamos: (a) Clair scanning nativo integrado a OCP, (b) sign policy mais
rica, (c) geo-replication entre clouds.

## Justificativa

1. **Latência e custo de egress** — OCIR intra-região para cluster OpenShift
   na mesma região OCI minimiza custo e latência de pull.
2. **Controle de dados** — OCIR sob tenancy OCI em `sa-saopaulo-1` atende
   requisito de residência de dados (B-R01 do risk register).
3. **Cosign é registry-agnóstico** — segurança de supply chain independe
   do registry escolhido.
4. **Operacional simples** — não assumir overhead de operar Quay self-hosted
   sem benefício claro.

## Consequências

### Positivas
- Build → push → pull todo na mesma região OCI (menor custo + latência).
- Sem introdução de novo provider SaaS (não vira item do risk register).
- IAM unificado com resto da infra OCI.

### Negativas
- Scanning nativo OCIR é menos profundo que Clair (Quay) — mitigado por
  Trivy no pipeline.
- Admission policy (Sigstore policy-controller) precisa ser instalada
  separadamente (não é nativo OCIR); documentado em Fase 05.
- Se ACS for adotado (ADR-004), parte da sinergia Quay↔ACS se perde.

## Notas de implementação (Fase 02 + 05 + 06)

- **Um repo por env**: `gateway-basa-sqa`, `gateway-basa-uat`, `gateway-basa-pro`.
- **Retention rules**:
  - sqa: keep last 10 tags.
  - uat: keep last 20 tags + todos `v*.*.*-rc*`.
  - pro: keep all `v*.*.*` tags (imutáveis) + last 30 outras tags.
- **Tag immutability** — ativada em pro, desativada em sqa.
- **Auth CI** — via OIDC Federation (Fase 06) usando `docker login` com
  token curto obtido de `oci iam` + chave de sessão.
- **Auth pull em OpenShift** — Image Pull Secret gerenciado pelo operator
  de secrets (External Secrets Operator lendo de OCI Vault).
- **URL padrão**: `{region-code}.ocir.io/{tenancy}/gateway-basa-{env}/gateway:{tag}`
  (ex: `gru.ocir.io/revenutech/gateway-basa-sqa/gateway:sqa-abc123`).

## Revisão

Reavaliar se:
- ACS (ADR-004) for adotado e integração com Quay trouxer ganho claro.
- Precisar de geo-replication entre clouds (migrar para Quay).
- OCIR impuser limitações de throughput / retention não mitigáveis.

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
