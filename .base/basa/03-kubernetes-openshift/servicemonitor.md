# ServiceMonitor — Prometheus Operator (OpenShift Monitoring)

**Arquiteto Principal:** Gustavo Armoa

## Objetivo

Expor métricas do Gateway ao **OpenShift User Workload Monitoring**
(Prometheus Operator nativo do OCP) via `ServiceMonitor` CR.

## Como o OpenShift expõe Prometheus

| Componente | Comportamento |
|---|---|
| Prometheus Operator | Nativo no OCP — habilitar via `enableUserWorkload: true` no `cluster-monitoring-config` |
| Label de scrape | ServiceMonitor sem label especial — Prometheus pega qualquer namespace user monitorado |
| Export cross-plataforma | OCI Monitoring pode receber via OTel (Fase 04) |
| Dashboards | Grafana Operator + Dashboards CR (Fase 04) |
| Alerting | `PrometheusRule` + Alertmanager |

## Habilitar User Workload Monitoring

Fora do chart (bootstrap do cluster). ConfigMap em `openshift-monitoring`:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: cluster-monitoring-config
  namespace: openshift-monitoring
data:
  config.yaml: |
    enableUserWorkload: true
    alertmanagerMain:
      enableUserAlertmanagerConfig: true
```

Em seguida, OpenShift provisiona automaticamente um Prometheus + Thanos
Ruler em `openshift-user-workload-monitoring`.

## ServiceMonitor — template atual (reutilizado)

`k8s/helm/gateway/templates/servicemonitor.yaml`:

```yaml
{{- if .Values.serviceMonitor.enabled }}
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: {{ include "gateway.fullname" . }}
  namespace: {{ .Release.Namespace }}
  labels:
    {{- include "gateway.labels" . | nindent 4 }}
spec:
  selector:
    matchLabels:
      app.kubernetes.io/name: gateway
      app.kubernetes.io/instance: {{ .Release.Name }}
  endpoints:
    - port: metrics
      interval: {{ .Values.serviceMonitor.interval | default "15s" }}
      path: /metrics
      scheme: http
      {{- if .Values.serviceMonitor.honorLabels }}
      honorLabels: true
      {{- end }}
  namespaceSelector:
    matchNames:
      - {{ .Release.Namespace }}
{{- end }}
```

ServiceMonitor é a API padrão — funciona sem customizações.

## Ajuste Basa — endpoint HTTPS (opcional)

Se service-ca (ADR-003) for ligado para scrape intra-cluster:

```yaml
endpoints:
  - port: metrics
    scheme: https
    tlsConfig:
      caFile: /etc/prometheus/configmaps/serving-certs-ca-bundle/service-ca.crt
      serverName: {{ include "gateway.fullname" . }}.{{ .Release.Namespace }}.svc
```

V1: `scheme: http` (mais simples, scrape intra-cluster confiável).

## PrometheusRule — alertas

Template `templates/prometheusrule.yaml` existente, reutilizado. Regras
principais:

```yaml
groups:
  - name: gateway.rules
    interval: 30s
    rules:
      - alert: GatewayHighErrorRate
        expr: rate(krakend_response_status_total{code=~"5.."}[5m]) > 0.05
        for: 5m
        labels:
          severity: critical
          service: gateway
        annotations:
          summary: "Gateway {{ $labels.instance }} — >5% 5xx nos últimos 5min"
      - alert: GatewayLatencyP99
        expr: histogram_quantile(0.99, rate(krakend_response_duration_seconds_bucket[5m])) > 1
        for: 10m
        labels:
          severity: warning
      - alert: GatewayPodNotReady
        expr: kube_pod_container_status_ready{namespace=~"gateway-.*", container="gateway"} == 0
        for: 5m
        labels:
          severity: critical
      - alert: GatewayCircuitBreakerOpen
        expr: rate(krakend_circuitbreaker_state{state="open"}[2m]) > 0
        for: 2m
        labels:
          severity: warning
      - alert: GatewayJWTFailureSpike
        expr: rate(krakend_jwt_validation_failures_total[5m]) > 5
        for: 5m
        labels:
          severity: warning
```

## Alertmanager em OpenShift

OCP tem **Alertmanager** próprio em `openshift-monitoring`. User alerts
roteiam para um Alertmanager separado em `openshift-user-workload-monitoring`.

Config Alertmanager user-workload (ConfigMap ou Secret
`alertmanager-user-workload` em `openshift-user-workload-monitoring`):

```yaml
route:
  receiver: default
  group_by: [alertname, severity]
  routes:
    - receiver: critical-slack
      match: { severity: critical }
    - receiver: warning-email
      match: { severity: warning }
receivers:
  - name: default
  - name: critical-slack
    slack_configs:
      - api_url_file: /etc/alertmanager/secrets/slack-url/url
        channel: '#gateway-alerts'
  - name: warning-email
    email_configs:
      - to: oncall@revenu.com.br
        from: alerts@revenu.com.br
        smarthost: smtp.gmail.com:587
```

Slack URL lido de Secret via OCI Vault (ESO sync).

## Cardinality / Labels

Cuidar com labels de alta cardinalidade (tenant_id, jwt_sub). Regras:

1. **Nunca** expor `jwt_sub` ou `user_id` como Prometheus label.
2. `tenant_id` sim (bounded set).
3. `endpoint`, `method`, `code` — ok.
4. HLC (Histogram) para duração — buckets default KrakenD.

## Bridge para OCI Monitoring

Opcional, Fase 04: exporter Prometheus → OCI Monitoring via OTel
Collector (remote_write sink). Mantém evidência redundante no OCI side.

## Decisões de design

1. **User Workload Monitoring habilitado** uma vez no cluster.
2. **ServiceMonitor reutilizado** do chart atual.
3. **PrometheusRule reutilizado** — regras de negócio independentes de
   cloud.
4. **HTTP scrape intra-cluster na v1**; HTTPS + service-ca fica plano B.
5. **Alertmanager user-workload** separado do platform.
6. **Cardinality controlada** — `tenant_id` ok; nada com PII.

## Controles ISO 27001

- A.8.15 — Logging (metrics são logs quantitativos).
- A.8.16 — Monitoring activities.
- A.5.25 — Assessment of security events.

## Checklist pronto-para-código

- [ ] `enableUserWorkload: true` aplicado ao cluster.
- [ ] ServiceMonitor descoberto pelo Prometheus OCP.
- [ ] Métricas `krakend_*` visíveis em console → Observe → Metrics.
- [ ] PrometheusRule carregada; `GatewayHighErrorRate` aparece em alertas.
- [ ] Alertmanager routes Slack/email funcionando (drill).
- [ ] Sem labels PII (`jwt_sub` ausente).

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
