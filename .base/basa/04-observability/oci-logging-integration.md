# OCI Logging & Monitoring — Bridge

## Objetivo

Documentar o bridge **opcional** entre a stack observability do OpenShift
(Prometheus/Loki/Tempo) e os serviços nativos OCI (**OCI Monitoring** e
**OCI Logging**), garantindo duplicação quando a auditoria OCI-nativa
for exigida.

## Por que bridge?

1. **Auditoria OCI-nativa** — compliance pode exigir evidência em
   ferramentas OCI-provided (independente do cluster OCP).
2. **SRE OCI-side** — time da Oracle que opera infra pode não ter acesso
   ao Grafana do cluster.
3. **Resiliência** — se o cluster OCP cair, ainda há visibilidade em OCI
   Monitoring/Logging.
4. **SLO cross-cloud** — OCI AD health signals complementam cluster metrics.

## Status — opcional, habilitado por env

| Env | Bridge métricas | Bridge logs | Bridge traces |
|---|---|---|---|
| dev | off | off | off |
| staging | on | off | off |
| prod | on | on | off (v1) |

## 1. Métricas — Prometheus remote_write → OCI Monitoring

OCI Monitoring expõe ingestion endpoint **limited PromQL-compatible**.

### Endpoint

```
POST https://telemetry-ingestion.{region}.oraclecloud.com/20180401/metrics
```

### Auth — OAuth2 Resource Principal

Criar:
1. **Dynamic group** `gateway-ocp-metrics-dg` com matching rule baseada
   em tag do cluster.
2. **Policy** `allow dynamic-group ... to use metrics in compartment ... where target.metrics.namespace='gateway_basa'`.
3. **Token** trocado periodicamente via Instance Principal.

### Config Prometheus (user-workload-monitoring-config)

```yaml
prometheus:
  remoteWrite:
    - url: https://telemetry-ingestion.sa-saopaulo-1.oraclecloud.com/20180401/metrics
      oauth2:
        clientId: {resource-principal-client-id}
        clientSecret:
          name: oci-monitoring-oauth
          key: client_secret
        tokenUrl: https://auth.sa-saopaulo-1.oraclecloud.com/v1/oauth2/token
        scopes: ["urn:opc:telemetry:metrics"]
      writeRelabelConfigs:
        - sourceLabels: [__name__]
          regex: 'krakend_.*|http_.*|up|process_.*'
          action: keep
        - sourceLabels: [namespace]
          regex: 'gateway-.*'
          action: keep
      headers:
        X-OCI-Metric-Namespace: gateway_basa
        X-OCI-Metric-ResourceGroup: gateway-{env}
```

### Métricas filtradas

Só exportar subset relevante para OCI (reduz custo, já que OCI bill por
data ingest):

- `krakend_response_status_total`
- `krakend_response_duration_seconds_bucket`
- `krakend_circuitbreaker_state`
- `krakend_jwt_validation_failures_total`
- `up`
- `kube_pod_status_phase` (para saber se pods rodam — complemento OCI)

### Dashboards OCI

Uma vez ingeridas, criar em OCI Management Dashboards:
- Gateway overview (espelho simplificado do Grafana).
- Alertas cruzados (OCI Alarms sobre as mesmas métricas).

## 2. Logs — ClusterLogForwarder → OCI Logging

OCI Logging aceita **PutLogs** API. Fluxo:

```
Vector (ClusterLogForwarder output type=http)
      ▼ HTTPS POST
OCI Logging Ingestion Endpoint
      ▼
Log Group (gateway-basa-{env}-app)
```

### ClusterLogForwarder — output

```yaml
outputs:
  - name: oci-logging
    type: http
    url: https://ingestion.logging.sa-saopaulo-1.oci.oraclecloud.com/20200831/actions/putLogs
    http:
      method: POST
      timeout: 30
      headers:
        Content-Type: application/json
        Authorization: ${env:OCI_AUTH_HEADER}     # assinado por ESO cronjob
  ...
pipelines:
  - name: prod-to-oci
    inputRefs: [application]
    outputRefs: [oci-logging, default-loki]
    filterRefs: [prod-only]
filters:
  - name: prod-only
    type: openshiftLabels
    openshiftLabels:
      namespaceIncludes: ["gateway-prod"]
```

### Signed request — desafio

OCI API usa **API signing** (RSA SHA-256 de canonical request). Vector
não sabe fazer nativo. Opções:

1. **Sidecar OCI Proxy** — container separado que assina requests e faz
   forward. Imagem custom construída sobre `oraclecloud/oci-cli`.
2. **Cronjob renova token** — Resource Principal troca por Session Token
   periódico, Vector usa Bearer.
3. **Service Connector Hub** — OCI ingere direto via Service Connector
   (alternativa se conseguirmos pushar logs em bucket ou source pluggable).

**V1 adota opção 3** — ClusterLogForwarder grava logs num **Object
Storage bucket** (S3-compat), Service Connector Hub lê do bucket e envia
para OCI Logging. Menos acoplamento, sem signing custom.

### ClusterLogForwarder — output para bucket

```yaml
outputs:
  - name: s3-archive
    type: http
    url: https://{namespace}.compat.objectstorage.{region}.oraclecloud.com/revenu-platform-log-bridge-{env}
    http:
      method: PUT
      headers:
        Authorization: "AWS4-HMAC-SHA256 ..."     # S3 SigV4 — Vector suporta
```

Alternativa cleaner: **`cloudwatch`** type no Vector (OCI não suporta
diretamente; seria via proxy). Decisão final via PoC em Fase 06.

## 3. Traces — OCI APM (opcional v2)

OCI APM aceita OTLP via endpoint:
```
https://aaaaaaaaaa.apm-agt.{region}.oci.oraclecloud.com/20200101/observations/public-span
```

Exportador OTLP HTTP no `otel-gateway` (Fase 04 anterior).

V1: **off**. Avaliar em v2 quando SRE OCI pedir.

## Custos do bridge (estimado)

- **OCI Monitoring remote_write:** ~$0.05 por milhão de data points. Com
  10k datapoints/min staging = $21/mês; prod = $60–100/mês.
- **OCI Logging ingest:** ~$0.40/GB. Com 5GB/dia prod = $60/mês.
- **OCI Object Storage (bridge bucket):** trivial (<$5/mês).

Total bridge prod ~$125–200/mês. Aceitar se auditoria OCI-nativa
obrigatória.

## Decisões de design

1. **Bridge opcional, off em dev.**
2. **Métricas via remote_write nativo** (Prometheus suporta).
3. **Logs via bucket intermediário** — evita complicação com OCI
   request signing no Vector.
4. **Traces via OCI APM ficam para v2**.
5. **Filtros rigorosos** — só subset necessário, controla custo.

## Controles ISO 27001

- A.8.15 — Logging (duplicação para OCI).
- A.8.16 — Monitoring activities (duplicação).
- A.5.33 — Protection of records (evidência OCI-side independente).
- A.5.23 — Information security for use of cloud services.

## Checklist pronto-para-código

- [ ] Dynamic group + policy para métricas configurados.
- [ ] Secret OAuth Prometheus → OCI Monitoring provisionado.
- [ ] Remote_write adicionado em user-workload-monitoring-config.
- [ ] Bucket bridge de logs existe (Terraform Fase 02).
- [ ] Service Connector Hub lê do bucket e escreve em Log Group OCI.
- [ ] Custos estimados revisados trimestralmente.
- [ ] Runbook de troubleshooting (perda de métrica no bridge) em Fase 08.
