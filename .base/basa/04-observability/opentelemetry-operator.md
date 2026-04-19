# OpenTelemetry Operator (Red Hat build)

## Objetivo

Coletar **traces** e opcionalmente **logs/métricas** via OTel, usando o
**Red Hat build of OpenTelemetry Operator** (supported) e provisionando
Collectors no cluster.

## Características

| Item | Detalhe |
|---|---|
| Operator | Red Hat OTel Operator + `OpenTelemetryCollector` CR |
| Exporters-alvo | Tempo + Loki (interno) + OCI APM opcional |
| Modo | Operator instala Collectors via CR (receiver/exporter declarativos) |
| Protocolos | gRPC :4317 / HTTP :4318 |

## Instalação

```yaml
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: opentelemetry-product
  namespace: openshift-operators
spec:
  channel: stable
  name: opentelemetry-product          # Red Hat build
  source: redhat-operators
  sourceNamespace: openshift-marketplace
```

Operator instala OperatorHub-manageable; CRs criáveis em qualquer namespace.

## Arquitetura — 2 Collectors

### DaemonSet — `otel-agent`

Um por node. Recebe OTLP de pods locais (sidecar-less).

```yaml
apiVersion: opentelemetry.io/v1alpha1
kind: OpenTelemetryCollector
metadata:
  name: otel-agent
  namespace: openshift-opentelemetry
spec:
  mode: daemonset
  image: registry.redhat.io/rhosdt/opentelemetry-collector-rhel8:latest
  serviceAccount: otel-collector
  resources:
    requests:
      cpu: 100m
      memory: 128Mi
    limits:
      cpu: 500m
      memory: 512Mi
  config: |
    receivers:
      otlp:
        protocols:
          grpc:
            endpoint: 0.0.0.0:4317
          http:
            endpoint: 0.0.0.0:4318
      hostmetrics:
        collection_interval: 60s
        scrapers:
          cpu:
          memory:
          disk:
          filesystem:
          network:
    processors:
      k8sattributes:
        auth_type: serviceAccount
        extract:
          metadata:
            - k8s.namespace.name
            - k8s.pod.name
            - k8s.pod.uid
            - k8s.node.name
      batch:
        timeout: 10s
        send_batch_size: 1024
      memory_limiter:
        check_interval: 1s
        limit_mib: 400
        spike_limit_mib: 100
    exporters:
      otlp:
        endpoint: otel-gateway.openshift-opentelemetry.svc:4317
        tls:
          insecure: true                # intra-cluster; plano B: service-ca
    service:
      pipelines:
        traces:
          receivers: [otlp]
          processors: [memory_limiter, k8sattributes, batch]
          exporters: [otlp]
```

### Deployment — `otel-gateway`

Recebe do agent e exporta para backends (Tempo, OCI APM, etc.).

```yaml
apiVersion: opentelemetry.io/v1alpha1
kind: OpenTelemetryCollector
metadata:
  name: otel-gateway
  namespace: openshift-opentelemetry
spec:
  mode: deployment
  replicas: 2
  serviceAccount: otel-collector
  resources:
    requests:
      cpu: 200m
      memory: 512Mi
    limits:
      cpu: 1000m
      memory: 2Gi
  config: |
    receivers:
      otlp:
        protocols:
          grpc:
            endpoint: 0.0.0.0:4317
          http:
            endpoint: 0.0.0.0:4318
    processors:
      tail_sampling:
        decision_wait: 10s
        num_traces: 50000
        policies:
          - name: sample-errors
            type: status_code
            status_code: { status_codes: [ERROR] }
          - name: sample-slow
            type: latency
            latency: { threshold_ms: 1000 }
          - name: sample-probabilistic
            type: probabilistic
            probabilistic: { sampling_percentage: 10 }
      batch:
        timeout: 10s
        send_batch_size: 1024
    exporters:
      otlp/tempo:
        endpoint: tempo-gateway.tempo.svc:4317
        tls:
          insecure: true
      otlphttp/oci_apm:
        endpoint: ${env:OCI_APM_ENDPOINT}
        headers:
          Authorization: ${env:OCI_APM_PRIVATE_KEY}
        tls:
          insecure: false
    service:
      pipelines:
        traces:
          receivers: [otlp]
          processors: [tail_sampling, batch]
          exporters: [otlp/tempo, otlphttp/oci_apm]
```

## KrakenD → OTel

O KrakenD CE 2.9.4 tem exportador OTLP via plugin `krakend-otelcollector`
ou config inline `telemetry/opentelemetry`:

```json
"extra_config": {
  "telemetry/opentelemetry": {
    "service_name": "gateway",
    "service_version": "{{ .Values.image.tag }}",
    "metric_reporting_period": 30,
    "trace_sample_rate": 0.1,
    "exporters": {
      "otlp": [
        {
          "name": "otel-agent",
          "host": "otel-agent.openshift-opentelemetry.svc",
          "port": 4317,
          "use_http": false,
          "disable_metrics": false,
          "disable_traces": false
        }
      ]
    },
    "layers": {
      "global": { "disable_propagation": false },
      "proxy": { "disable_metrics": false },
      "backend": { "metrics": { "disable_stage": false }, "traces": { "report_headers": false } }
    }
  }
}
```

Isso entra via FC template ou settings aplicados em Fase 03.

## Tempo Operator (traces storage)

Instalar **Tempo Operator** via OperatorHub. TempoStack CR:

```yaml
apiVersion: tempo.grafana.com/v1alpha1
kind: TempoStack
metadata:
  name: tempo-gateway
  namespace: tempo
spec:
  storageSize: 100Gi
  storage:
    secret:
      name: tempo-objstore
      type: s3
  resources:
    total:
      limits:
        cpu: 2000m
        memory: 4Gi
  template:
    queryFrontend:
      jaegerQuery:
        enabled: true
```

Backend: OCI Object Storage (S3-compat) bucket `revenu-platform-tempo-{env}`.

## Sampling

- **Head sampling** no KrakenD: 10% dos spans por default.
- **Tail sampling** no otel-gateway:
  - 100% spans com erro.
  - 100% spans > 1s.
  - 10% probabilistic para baseline.

Ajustável por env.

## Métricas via OTel (opcional)

Pipeline separado pode ingerir métricas via OTel (prometheus receiver +
otlp exporter para Prometheus remote_write). **Não é necessário v1** —
OpenShift Monitoring já cuida.

## Logs via OTel (opcional)

OTel Collector pode receber logs e exportar para Loki. **Não usar na v1**
— OpenShift Logging (Vector + Loki) é mais simples.

## Decisões de design

1. **Two-tier collector** (agent DaemonSet + gateway Deployment) —
   isolamento de falha, sampling centralizado.
2. **Traces como prioridade v1**, métricas e logs ficam com stack dedicada.
3. **Tempo Operator** — backend supported RH.
4. **OCI APM exporter opcional** — liga se quisermos traces visíveis em
   OCI Console (útil para SRE OCI-side).
5. **Head sampling 10% + tail sampling 100% erros/slow** — balance custo
   × observabilidade.

## Controles ISO 27001

- A.8.15 — Logging (traces são forma de logging).
- A.8.16 — Monitoring activities.

## Checklist pronto-para-código

- [ ] Operator Red Hat OTel instalado.
- [ ] `otel-agent` DaemonSet ativo em todos os nodes.
- [ ] `otel-gateway` Deployment ativo (2 replicas).
- [ ] KrakenD com OTLP exporter habilitado.
- [ ] Tempo Operator instalado + TempoStack rodando.
- [ ] Traces visíveis em Grafana Explore via datasource Tempo.
- [ ] Bucket Tempo config S3-compat apontando para OCI Object Storage.
- [ ] OCI APM exporter opcional — se ligado, traces aparecem em OCI APM.
