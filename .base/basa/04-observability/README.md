# Fase 04 — Observabilidade

**Arquiteto Principal:** Gustavo Armoa

Stack de métricas, logs, traces e dashboards do Gateway no track Basa,
baseada em **OpenShift Monitoring** (Prometheus Operator nativo) +
**Grafana Operator** + **Red Hat build of OpenTelemetry Operator** +
**OpenShift Logging (Loki)**, com bridge opcional para OCI Monitoring e
OCI Logging.

## Arquivos

| Documento | Foco |
|---|---|
| [prometheus-operator.md](prometheus-operator.md) | Cluster Monitoring + User Workload Monitoring, retention, remote_write |
| [grafana-operator.md](grafana-operator.md) | Grafana Operator, GrafanaDashboard CR, datasources |
| [opentelemetry-operator.md](opentelemetry-operator.md) | RH build of OTel, OTel Collector (Deployment + DaemonSet), traces |
| [logging-loki.md](logging-loki.md) | OpenShift Logging via ClusterLogging + Loki |
| [oci-logging-integration.md](oci-logging-integration.md) | Bridge OTel Collector → OCI Logging + OCI Monitoring |

## Princípios

1. **Operators nativos do OpenShift** — Prometheus, Grafana, OTel, Logging.
   Nada instalado via Helm "bare".
2. **GitOps-friendly** — CRs versionados em `k8s/manifests-openshift/observability/`.
3. **Cardinality sob controle** — regras claras de labels (já em Fase 03).
4. **Retenção alinhada com compliance** — métricas 14d, logs 30d (quentes) +
   archive 7 anos (A.5.33).
5. **Bridge opcional para OCI** — mesmas métricas/logs visíveis em OCI Monitoring/Logging para auditoria OCI-nativa.

## Componentes e responsabilidade

```
┌──────────────────────────────┐
│ Pods do Gateway (:8090)      │
└─────────┬────────────────────┘
          │ scrape
          ▼
┌──────────────────────────────┐
│ Prometheus (User Workload    │
│ Monitoring, OCP nativo)      │
│ retenção: 14d                │
└─────────┬──────────┬─────────┘
          │ query    │ remote_write (opcional)
          ▼          ▼
┌──────────────┐  ┌──────────────┐
│ Grafana      │  │ OCI Monitor  │
│ (Operator)   │  │ (bridge OTel)│
└──────────────┘  └──────────────┘

┌──────────────────────────────┐
│ Pods do Gateway (stdout)     │
└─────────┬────────────────────┘
          │ collected
          ▼
┌──────────────────────────────┐
│ Vector (ClusterLogForwarder) │
│ → Loki (operator)            │
│ retenção: 30d                │
└─────────┬──────────┬─────────┘
          │ query    │ forward OCI Logging
          ▼          ▼
┌──────────────┐  ┌──────────────┐
│ Grafana Loki │  │ OCI Logging  │
└──────────────┘  └──────────────┘

┌──────────────────────────────┐
│ KrakenD OTel exporter        │
│ (traces — port 4317)         │
└─────────┬────────────────────┘
          ▼
┌──────────────────────────────┐
│ OTel Collector (DaemonSet)   │
│ sampling: tailsampling 10%   │
└─────────┬────────────────────┘
          ▼
┌──────────────────────────────┐
│ Tempo Operator (traces)      │
│ storage: S3/Object Storage   │
└──────────────────────────────┘
```

## Checklist de fechamento da Fase 04

- [ ] User Workload Monitoring ativo no cluster (Fase 03 já marca).
- [ ] Grafana Operator instalado; Grafana CR rodando.
- [ ] Dashboards-alvo criados como `GrafanaDashboard` CRs versionados.
- [ ] OTel Operator instalado; Collector DaemonSet em cada node.
- [ ] OpenShift Logging (Loki) coletando logs do namespace gateway.
- [ ] Bridge OCI Logging opcionalmente ativada.
- [ ] Retenção documentada e auditável.
- [ ] Runbook de recuperação de série de métricas longa (Fase 08).

## Controles ISO 27001

- A.5.25 — Assessment and decision on information security events.
- A.5.33 — Protection of records (retention logs + métricas).
- A.8.15 — Logging.
- A.8.16 — Monitoring activities.
- A.8.17 — Clock synchronization (NTP nos nodes RHCOS).

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
