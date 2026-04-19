# Fase 04 — Observabilidade

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
