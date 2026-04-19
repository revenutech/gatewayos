# Values per Environment — Basa

## Objetivo

Estrutura e defaults dos arquivos `values-oci-{sqa,uat,pro}.yaml` a
serem criados em `k8s/helm/gateway/` quando Fase 03 for executada.

## Localização dos arquivos

```
k8s/helm/gateway/
├── values.yaml                      # defaults
├── values-oci-sqa.yaml
├── values-oci-uat.yaml
└── values-oci-pro.yaml
```

## Bloco comum a todos `values-oci-*.yaml`

```yaml
openshift:
  scc:
    create: false           # usar restricted-v2 default
  route:
    enabled: true
    tlsTermination: edge
    insecureEdgeTerminationPolicy: Redirect
    wildcardPolicy: None
    annotations:
      haproxy.router.openshift.io/timeout: "30s"
      haproxy.router.openshift.io/hsts_header: "max-age=31536000;includeSubDomains;preload"

certManager:
  enabled: true
  issuerRef:
    kind: ClusterIssuer
    # uat em sqa, pro em uat/pro
  duration: 2160h           # 90d
  renewBefore: 360h         # 15d

# Pull secret sincronizado via ESO (Fase 05)
image:
  pullSecret: ocir-pull

krakend:
  fcEnable: "0"
  port: "8080"
  usageDisable: "1"

labels:
  app.kubernetes.io/name: gateway
  app.kubernetes.io/component: api-gateway
  app.kubernetes.io/part-of: revenu-platform
  platform.revenu/track: basa
  platform.revenu/iso27001: "true"

serviceMonitor:
  enabled: true
  interval: 15s

prometheusRule:
  enabled: true

networkPolicy:
  enabled: true
  # backends preenchidos por env
```

## `values-oci-sqa.yaml`

```yaml
{{/* herda comum */}}

image:
  repository: gru.ocir.io/revenutech/gateway-basa-sqa/gateway
  tag: sqa-latest
  pullPolicy: Always
  pullSecret: ocir-pull

replicaCount: 1

resources:
  requests:
    cpu: 100m
    memory: 64Mi
  limits:
    cpu: 500m
    memory: 256Mi

autoscaling:
  enabled: true
  minReplicas: 1
  maxReplicas: 3
  targetCPUUtilizationPercentage: 70
  targetMemoryUtilizationPercentage: 80

pdb:
  enabled: false            # sqa: tolera down total

openshift:
  route:
    host: gateway.sqa.oci.allenty.io

certManager:
  issuerRef:
    name: letsencrypt-staging     # evita rate-limit LE
  commonName: gateway.sqa.oci.allenty.io
  dnsNames:
    - gateway.sqa.oci.allenty.io

krakend:
  env: sqa

networkPolicy:
  backends:
    - namespace: ledgeros-sqa
      app: ledgeros
      port: 8081
    - namespace: paymentos-sqa
      app: paymentos
      port: 8082
    - namespace: identos-sqa
      app: identos
      port: 8091
    - namespace: atmos-sqa
      app: atmos
      port: 8088

prometheusRule:
  enabled: false             # sqa: ruído alto, sem on-call
```

## `values-oci-uat.yaml`

```yaml
image:
  repository: gru.ocir.io/revenutech/gateway-basa-uat/gateway
  tag: uat-latest
  pullPolicy: Always
  pullSecret: ocir-pull

replicaCount: 2

resources:
  requests:
    cpu: 250m
    memory: 128Mi
  limits:
    cpu: 1000m
    memory: 512Mi

autoscaling:
  enabled: true
  minReplicas: 2
  maxReplicas: 6
  targetCPUUtilizationPercentage: 60
  targetMemoryUtilizationPercentage: 75

pdb:
  enabled: true
  maxUnavailable: 1

openshift:
  route:
    host: gateway.uat.oci.allenty.io

certManager:
  issuerRef:
    name: letsencrypt-prod
  commonName: gateway.uat.oci.allenty.io
  dnsNames:
    - gateway.uat.oci.allenty.io

krakend:
  env: uat

networkPolicy:
  backends:
    - namespace: ledgeros-uat
      app: ledgeros
      port: 8081
    - namespace: paymentos-uat
      app: paymentos
      port: 8082
    - namespace: identos-uat
      app: identos
      port: 8091
    - namespace: atmos-uat
      app: atmos
      port: 8088
```

## `values-oci-pro.yaml`

```yaml
image:
  repository: gru.ocir.io/revenutech/gateway-basa-pro/gateway
  # tag OVERRIDE via --set no CD
  tag: v1.0.0
  pullPolicy: IfNotPresent
  pullSecret: ocir-pull

replicaCount: 3

resources:
  requests:
    cpu: 500m
    memory: 256Mi
  limits:
    cpu: 2000m
    memory: 1Gi

autoscaling:
  enabled: true
  minReplicas: 3
  maxReplicas: 10
  targetCPUUtilizationPercentage: 60
  targetMemoryUtilizationPercentage: 75

pdb:
  enabled: true
  minAvailable: 2

openshift:
  route:
    host: gateway.oci.allenty.io

certManager:
  issuerRef:
    name: letsencrypt-prod
  commonName: gateway.oci.allenty.io
  dnsNames:
    - gateway.oci.allenty.io

krakend:
  env: pro

networkPolicy:
  backends:
    - namespace: ledgeros-pro
      app: ledgeros
      port: 8081
    - namespace: paymentos-pro
      app: paymentos
      port: 8082
    - namespace: identos-pro
      app: identos
      port: 8091
    - namespace: atmos-pro
      app: atmos
      port: 8088

prometheusRule:
  enabled: true

# Annotations extras em pro
annotations:
  platform.revenu/change-ticket: ""  # setado pelo pipeline
```

## Variáveis setadas no pipeline (override `--set`)

- `image.tag` — SHA do commit (`sqa-abc123`) ou tag (`v1.0.0`).
- `configHash` — SHA do config compilado.
- `annotations.platform\.revenu/change-ticket` — ID do PR/ticket (pro).

## Diferenças sintéticas sqa → uat → pro

| Atributo | sqa | uat | pro |
|---|---|---|---|
| Replicas iniciais | 1 | 2 | 3 |
| CPU req | 100m | 250m | 500m |
| Memory req | 64Mi | 128Mi | 256Mi |
| HPA max | 3 | 6 | 10 |
| PDB | — | maxUnavail 1 | minAvail 2 |
| LE issuer | uat | pro | pro |
| Image pull | Always | Always | IfNotPresent |
| PrometheusRule | off | on | on |
| Change ticket annotation | n/a | n/a | obrigatório |

## Validação

```
for env in sqa uat pro; do
  helm lint k8s/helm/gateway -f k8s/helm/gateway/values-oci-${env}.yaml
  helm template gateway k8s/helm/gateway -f k8s/helm/gateway/values-oci-${env}.yaml \
    | kubeconform -strict -schema-location default -schema-location 'https://raw.githubusercontent.com/.../openshift-json-schema/master/{{.ResourceKind}}-{{.ResourceAPIVersion}}.json'
done
```

## Checklist pronto-para-código

- [ ] 3 arquivos `values-oci-*.yaml` criados.
- [ ] `helm lint` passa em cada um.
- [ ] `helm template` renderiza Route + Certificate + Deployment sem
      `runAsUser` fixo.
- [ ] Backends do NetworkPolicy refletem realidade de cada env.
- [ ] Prod com PDB `minAvailable: 2` e HPA `max: 10`.
