# Grafana Operator

## Objetivo

Instalar e configurar **Grafana Operator** (grafana-operator.github.io) no
OpenShift, provisionar uma instância Grafana, datasources (Prometheus +
Loki + Tempo) e **portar os dashboards existentes** do track GCP como
`GrafanaDashboard` CRs.

## Equivalência

| GCP | Basa |
|---|---|
| Grafana em GKE namespace dedicado (`dashboard.allenty.io`) | Grafana Operator instala Grafana no namespace `gateway-observability` |
| Cloud Monitoring dashboards | `GrafanaDashboard` CRs versionados em git |
| GKE ManagedCertificate TLS | Route edge + cert-manager (mesmo modelo de Fase 03) |
| Plugin install inline | Plugin install via `GrafanaInstance.spec.deployment.spec.template.spec.initContainers` |

## Instalação

Via OperatorHub:

```
oc apply -f - <<EOF
apiVersion: operators.coreos.com/v1
kind: OperatorGroup
metadata:
  name: grafana-operator
  namespace: gateway-observability
---
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: grafana-operator
  namespace: gateway-observability
spec:
  channel: v5
  name: grafana-operator
  source: community-operators
  sourceNamespace: openshift-marketplace
EOF
```

**Namespace:** `gateway-observability` (compartilhado entre dashboards de
múltiplos apps no futuro).

## Grafana CR

```yaml
apiVersion: grafana.integreatly.org/v1beta1
kind: Grafana
metadata:
  name: gateway-grafana
  namespace: gateway-observability
  labels:
    dashboards: gateway        # selector usado pelos GrafanaDashboard
spec:
  config:
    log:
      mode: "console"
    auth:
      disable_login_form: "false"
    auth.anonymous:
      enabled: "false"
    users:
      viewers_can_edit: "false"
    security:
      admin_user: admin
      admin_password: $__env{GF_SECURITY_ADMIN_PASSWORD}
    server:
      root_url: "https://dashboard.oci.allenty.io"
  deployment:
    spec:
      replicas: 1
      template:
        spec:
          containers:
            - name: grafana
              env:
                - name: GF_SECURITY_ADMIN_PASSWORD
                  valueFrom:
                    secretKeyRef:
                      name: grafana-admin
                      key: password
  service:
    spec:
      type: ClusterIP
  route:
    spec:
      host: dashboard.oci.allenty.io
      tls:
        termination: edge
        insecureEdgeTerminationPolicy: Redirect
```

Secret `grafana-admin` populado via ESO (Fase 05).

## Datasources

### Prometheus (user workload)

```yaml
apiVersion: grafana.integreatly.org/v1beta1
kind: GrafanaDatasource
metadata:
  name: prometheus-user-workload
  namespace: gateway-observability
spec:
  instanceSelector:
    matchLabels:
      dashboards: gateway
  datasource:
    name: Prometheus
    type: prometheus
    access: proxy
    url: https://thanos-querier.openshift-monitoring.svc:9091
    isDefault: true
    jsonData:
      tlsSkipVerify: false
      httpMethod: POST
      customQueryParameters: "namespace=gateway-{env}"
      oauthPassThru: true
    secureJsonData:
      httpHeaderValue1: "Bearer $__file{/var/run/secrets/kubernetes.io/serviceaccount/token}"
```

> **Nota:** Grafana precisa de RBAC para consultar Prometheus OCP. Usar
> ServiceAccount com `cluster-monitoring-view` ClusterRole.

### Loki

```yaml
apiVersion: grafana.integreatly.org/v1beta1
kind: GrafanaDatasource
metadata:
  name: loki-openshift
  namespace: gateway-observability
spec:
  instanceSelector:
    matchLabels:
      dashboards: gateway
  datasource:
    name: Loki
    type: loki
    access: proxy
    url: https://logging-loki-gateway-http.openshift-logging.svc:8080
    jsonData:
      tlsSkipVerify: false
```

### Tempo (traces)

```yaml
apiVersion: grafana.integreatly.org/v1beta1
kind: GrafanaDatasource
metadata:
  name: tempo
  namespace: gateway-observability
spec:
  instanceSelector:
    matchLabels:
      dashboards: gateway
  datasource:
    name: Tempo
    type: tempo
    access: proxy
    url: http://tempo-gateway.tempo.svc:3200
```

## Dashboards portados

Cada dashboard existente (GCP Cloud Monitoring) vira um JSON +
`GrafanaDashboard` CR.

### Estrutura no repo

```
k8s/manifests-openshift/observability/dashboards/
├── gateway-overview.yaml          # GrafanaDashboard CR
├── gateway-overview.json          # JSON do dashboard
├── gateway-latency.yaml
├── gateway-latency.json
├── gateway-errors.yaml
├── gateway-errors.json
├── gateway-security.yaml          # JWT failures, rate-limit hits
└── gateway-security.json
```

### CR típica

```yaml
apiVersion: grafana.integreatly.org/v1beta1
kind: GrafanaDashboard
metadata:
  name: gateway-overview
  namespace: gateway-observability
spec:
  instanceSelector:
    matchLabels:
      dashboards: gateway
  resyncPeriod: 1h
  configMapRef:
    name: gateway-overview-json
    key: dashboard.json
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: gateway-overview-json
  namespace: gateway-observability
data:
  dashboard.json: |
    { ...JSON exportado do Grafana existente... }
```

### Dashboards-alvo

| Dashboard | Painéis principais |
|---|---|
| **gateway-overview** | Requests/s, p50/p95/p99 latency, error rate, pods up, CPU/mem |
| **gateway-latency** | Latency por endpoint, por backend, por tenant |
| **gateway-errors** | 4xx por endpoint, 5xx por backend, circuit breaker state |
| **gateway-security** | JWT validation failures, rate limit hits por tenant, bloom filter stats |
| **gateway-sli** | SLO burn rate, budget remaining |

## RBAC

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: grafana-sa
  namespace: gateway-observability
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: grafana-monitoring-view
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-monitoring-view
subjects:
  - kind: ServiceAccount
    name: grafana-sa
    namespace: gateway-observability
```

Grafana Deployment deve usar `serviceAccountName: grafana-sa`.

## Route TLS

Idêntico ao Route do Gateway (Fase 03): edge termination + cert-manager
emitindo cert para `dashboard.oci.allenty.io`.

## Decisões de design

1. **Grafana Operator, não Grafana standalone** — CRs versionáveis, GitOps-friendly.
2. **Namespace `gateway-observability`** — separado do `gateway-{env}`, compartilhável.
3. **Single instância**, sem HA na v1 — Grafana é leitura; lote de dashboards baixo.
4. **Dashboards versionados como JSON em ConfigMap** — simples; pode evoluir para Kustomize overlay.
5. **Anonymous desabilitado** — login via admin credential (ESO); SSO fica plano B.

## Controles ISO 27001

- A.8.16 — Monitoring activities.
- A.5.15 — Access control (Grafana admin).
- A.8.2 — Privileged access (RBAC Grafana SA).

## Checklist pronto-para-código

- [ ] Grafana Operator instalado via OperatorHub.
- [ ] `Grafana` CR rodando, Route `dashboard.oci.allenty.io` ativo.
- [ ] Datasources Prometheus + Loki + Tempo provisionados e `Working`.
- [ ] Dashboards-alvo importados como CRs.
- [ ] Admin login funciona; anonymous off.
- [ ] Cert emitido pelo cert-manager.
