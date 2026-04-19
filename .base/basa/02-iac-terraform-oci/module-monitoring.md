# Module — Monitoring

**Arquiteto Principal:** Gustavo Armoa

## Objetivo

Provisionar a camada de **OCI Monitoring + Logging** para métricas,
alarmes e logs (infra-level). Complementa, não substitui, o OpenShift
Monitoring (Prometheus/Grafana) detalhado na Fase 04.

## Recursos OCI envolvidos

| Finalidade | Tipo OCI |
|---|---|
| Alarmes | `oci_monitoring_alarm` |
| Dashboards | `oci_management_dashboard` (JSON) |
| Métricas derivadas de logs | `oci_logging_log` + Log Search metrics |
| Export de logs | `oci_sch_service_connector` (Service Connector Hub) |
| Log aggregation | `oci_logging_log_group` + `oci_logging_log` |
| Notificação | `oci_ons_notification_topic` + subscriptions |

## Escopo deste módulo

Infra-level (OCI side), **não Prometheus**. Cobre:
- Alarmes de saúde de compute instances (CPU, memória, boot disk).
- Alarmes de Load Balancer (backend unhealthy, SSL expiration).
- Alarmes de OCIR (upload failures, scan criticals).
- Central log aggregation — VCN flow logs + audit logs + LB access logs.
- Service Connector para export opcional a Object Storage (retenção longa).

O que está em Fase 04 (Prometheus / Grafana / OTel): métricas dos pods,
dashboards de app, Alertmanager para alertas de workload.

## Inputs

```hcl
variable "compartment_id"       { type = string }
variable "environment"          { type = string }
variable "ocp_cluster_name"     { type = string }
variable "lb_ingress_ocid"      { type = string }
variable "lb_api_ocid"          { type = string }
variable "vcn_id"               { type = string }
variable "notification_email"   { type = string }                 # oncall inicial
variable "slack_webhook_topic"  { type = string, default = "" }   # opcional
variable "defined_tags"         { type = map(string) }
```

## Recursos

### Logging

| Nome TF | Tipo OCI | Finalidade |
|---|---|---|
| `log_group_security` | `oci_logging_log_group` | security logs (audit, flow) |
| `log_group_app` | `oci_logging_log_group` | logs aplicacionais (se não via Loki) |
| `log_vcn_flow` | `oci_logging_log` | flow logs da VCN (ativado no módulo vcn) |
| `log_audit` | `oci_logging_log` | audit events OCI (config-level, IAM changes) |
| `log_lb_access` | `oci_logging_log` | LB ingress access logs |

### Notifications

| Nome TF | Tipo OCI | Finalidade |
|---|---|---|
| `topic_critical` | `oci_ons_notification_topic` | Alarmes críticos |
| `topic_warning` | `oci_ons_notification_topic` | Alarmes warning |
| `sub_email_critical` | `oci_ons_subscription` | Email oncall |
| `sub_slack_critical` | `oci_ons_subscription` | Slack (HTTPS webhook) se configurado |

### Alarmes (mínimo)

| Nome | Métrica | Threshold | Severity | Topic |
|---|---|---|---|---|
| `alarm_master_cpu` | CPU master nodes | `> 85%` por 10m | WARNING | topic_warning |
| `alarm_worker_cpu` | CPU workers | `> 80%` por 15m | WARNING | topic_warning |
| `alarm_lb_backend_unhealthy` | `UnhealthyBackendServers` | `> 0` por 5m | CRITICAL | topic_critical |
| `alarm_lb_5xx` | `HTTPResponses` filter 5xx | `> 10/min` por 5m | CRITICAL | topic_critical |
| `alarm_ocir_scan_critical` | Custom (Log Search) — CVE critical in last scan | `> 0` | CRITICAL | topic_critical |
| `alarm_kms_usage_anomaly` | `KMS.RequestCount` variação > 3σ | CRITICAL | topic_critical |
| `alarm_nat_port_exhaustion` | `NatPortAllocationUtilization` | `> 80%` | WARNING | topic_warning |
| `alarm_storage_boot_vol` | Boot volume used % | `> 85%` | WARNING | topic_warning |

## Service Connector Hub

Para arquivar logs para Object Storage (90+ dias):

```hcl
resource "oci_sch_service_connector" "archive" {
  source {
    kind = "logging"
    log_sources = [
      { log_group_id = oci_logging_log_group.log_group_security.id }
    ]
  }
  target {
    kind        = "objectStorage"
    bucket      = oci_objectstorage_bucket.log_archive.name
    namespace   = data.oci_objectstorage_namespace.ns.namespace
    batch_rollover_size_in_mbs = 100
    batch_rollover_time_in_ms  = 300000
  }
}
```

Retention Object Storage: 7 anos para audit logs (A.5.33 — Protection of records).

## Outputs

```hcl
output "topic_critical_ocid"     { value = oci_ons_notification_topic.topic_critical.id }
output "topic_warning_ocid"      { value = oci_ons_notification_topic.topic_warning.id }
output "log_group_security_ocid" { value = oci_logging_log_group.log_group_security.id }
output "log_group_app_ocid"      { value = oci_logging_log_group.log_group_app.id }
output "archive_bucket_name"     { value = oci_objectstorage_bucket.log_archive.name }
```

## Dashboards

OCI Management Dashboards — JSON versionado em `modules/monitoring/dashboards/`:

- `gateway-infra.json` — métricas de compute + LB + KMS + NAT.
- `gateway-security.json` — audit events, IAM changes, flow anomalies.

Dashboards de **workload (Prometheus)** ficam em Fase 04.

## Decisões de design

1. **OCI Monitoring + OpenShift Monitoring coexistem** — cobertura dupla
   (infra + workload). Sem deduplicação; foco é complementar.
2. **Email como primeiro canal** — Slack fica opcional (evita dependência
   de webhook não-gerenciado pela OCI).
3. **Arquivamento para Object Storage** com lifecycle para Archive Tier
   após 30 dias (custo-efetivo para 7 anos).
4. **Logs ficam na OCI por default** — Bridge opcional para central de
   logs em Fase 04 via OTel quando exigido.

## Controles ISO 27001

- A.8.15 — Logging.
- A.8.16 — Monitoring activities.
- A.5.25 — Assessment and decision on information security events.
- A.5.33 — Protection of records (retention 7 anos).

## Checklist pronto-para-código

- [ ] `modules/monitoring/main.tf` + dashboards JSON.
- [ ] Alarmes disparam email em drill test.
- [ ] Service Connector arquiva security logs em Object Storage.
- [ ] Lifecycle policy no bucket de archive configurada.
- [ ] IRP (Fase 08) referencia topic OCIDs para escalonamento.

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
