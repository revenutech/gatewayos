# Prometheus Operator — OpenShift Monitoring

## Objetivo

Configurar o stack de métricas nativo do OpenShift (cluster + user
workload monitoring), retention adequada, remote_write opcional para
bridge externa e integração com Alertmanager.

## Equivalência

| GCP | Basa |
|---|---|
| Cloud Monitoring ingere via GKE integration | OpenShift nativo — Prometheus + Thanos Ruler |
| Custom Prometheus no GKE | `openshift-user-workload-monitoring` namespace (fornecido) |
| Retenção ilimitada Cloud Monitoring | Prometheus retenção finita + arquivo Thanos (opcional) |
| PromQL via Grafana custom | PromQL via Console OCP + Grafana Operator |

## Stack nativo

| Componente | Namespace | Papel |
|---|---|---|
| Prometheus (platform) | `openshift-monitoring` | métricas do cluster (kubelet, apiserver, etc.) |
| Thanos Ruler (platform) | `openshift-monitoring` | avalia rules cluster |
| Alertmanager (platform) | `openshift-monitoring` | alertas platform |
| Prometheus (user workload) | `openshift-user-workload-monitoring` | métricas de apps |
| Thanos Ruler (user workload) | `openshift-user-workload-monitoring` | rules de apps |
| Alertmanager (user workload) | `openshift-user-workload-monitoring` | alertas de apps (separado) |

## Ativação do User Workload Monitoring

ConfigMap em `openshift-monitoring`:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: cluster-monitoring-config
  namespace: openshift-monitoring
data:
  config.yaml: |
    enableUserWorkload: true
```

E ajuste em `openshift-user-workload-monitoring/user-workload-monitoring-config`:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: user-workload-monitoring-config
  namespace: openshift-user-workload-monitoring
data:
  config.yaml: |
    prometheus:
      retention: 14d
      retentionSize: 40GiB
      volumeClaimTemplate:
        spec:
          storageClassName: oci-bv               # OCI Block Volume CSI
          resources:
            requests:
              storage: 50Gi
      # Remote write para OCI Monitoring (opcional — ver oci-logging-integration.md)
      remoteWrite: []
      resources:
        requests:
          cpu: 200m
          memory: 1Gi
    alertmanager:
      enabled: true
      enableAlertmanagerConfig: true
      volumeClaimTemplate:
        spec:
          storageClassName: oci-bv
          resources:
            requests:
              storage: 10Gi
    thanosRuler:
      retention: 14d
      volumeClaimTemplate:
        spec:
          storageClassName: oci-bv
          resources:
            requests:
              storage: 20Gi
```

## ServiceMonitor + PrometheusRule do Gateway

Já detalhados em Fase 03 (`03-kubernetes-openshift/servicemonitor.md`).
Reutilização direta — nada novo aqui.

## AlertmanagerConfig (namespace user)

CRD `monitoring.coreos.com/v1alpha1` — cada time pode ter o seu.

```yaml
apiVersion: monitoring.coreos.com/v1alpha1
kind: AlertmanagerConfig
metadata:
  name: gateway-routing
  namespace: gateway-{env}
spec:
  route:
    receiver: gateway-critical
    groupBy: [alertname, severity]
    routes:
      - receiver: gateway-critical
        matchers:
          - name: severity
            value: critical
      - receiver: gateway-warning
        matchers:
          - name: severity
            value: warning
  receivers:
    - name: gateway-critical
      slackConfigs:
        - apiURL:
            name: slack-webhook
            key: url
          channel: '#gateway-critical'
          sendResolved: true
    - name: gateway-warning
      emailConfigs:
        - to: oncall@revenu.com.br
          from: alerts@revenu.com.br
          smarthost: smtp.gmail.com:587
          sendResolved: true
```

Secret `slack-webhook` criado via External Secrets Operator a partir de
OCI Vault.

## Remote write (bridge)

Para espelhar métricas em OCI Monitoring ou em plataforma centralizada
multi-cloud:

```yaml
prometheus:
  remoteWrite:
    - url: https://telemetry-ingestion.{region}.oci.oraclecloud.com/20180401/metrics
      oauth2:
        clientId: {client_id}
        clientSecret:
          name: oci-monitoring-secret
          key: client_secret
        tokenUrl: https://auth.{region}.oraclecloud.com/v1/oauth2/token
      writeRelabelConfigs:
        - sourceLabels: [__name__]
          regex: 'krakend_.*|http_.*'           # só essas famílias
          action: keep
```

Detalhe de auth OCI Monitoring fica em `oci-logging-integration.md`.

## Retention

| Série | Retenção local (Prom) | Archive |
|---|---|---|
| Platform | 14d | — |
| User workload | 14d | — |
| Thanos Ruler evaluated rules | 14d | — |

Para retenção >14d (compliance / trend analysis longo), adotar **Thanos
com Object Storage** (OCI Object Storage é S3-compatible):

```yaml
prometheus:
  thanos:
    objectStorageConfig:
      name: thanos-objstore
      key: thanos.yaml
```

Secret `thanos-objstore` com config S3-compatible:

```yaml
type: S3
config:
  bucket: revenu-platform-thanos-{env}
  endpoint: {namespace}.compat.objectstorage.{region}.oraclecloud.com
  access_key: {customer_secret_key_id}
  secret_key: {customer_secret_key}
  signature_version2: false
  insecure: false
```

Documentar bucket no Terraform OCI (Fase 02 — monitoring module).

## Console integration

OCP Console → Observe → Metrics / Alerts / Targets. Admin e user view
separados; user view vê apenas namespaces com label
`openshift.io/user-monitoring: "true"`.

## Decisões de design

1. **14d retention** no Prometheus — alinhado com OCP default; >14d via Thanos.
2. **Alertmanager user-workload separado** do platform.
3. **AlertmanagerConfig por namespace** — time gerencia seu próprio routing.
4. **Remote write opcional** — liga se OCI Monitoring for exigência.
5. **Secrets do Alertmanager** via ESO + OCI Vault.

## Controles ISO 27001

- A.8.16 — Monitoring activities.
- A.8.15 — Logging (alerts como eventos).
- A.5.25 — Assessment of security events.
- A.5.33 — Protection of records (Thanos archive).

## Checklist pronto-para-código

- [ ] `enableUserWorkload: true` + config aplicados.
- [ ] ServiceMonitor do Gateway discovered; targets `UP`.
- [ ] AlertmanagerConfig aplicado por namespace.
- [ ] Slack webhook drill envia mensagem.
- [ ] Thanos objstore config opcional — bucket OCI + secret.
- [ ] Remote write opcional testado (ou documentado se desligado).
