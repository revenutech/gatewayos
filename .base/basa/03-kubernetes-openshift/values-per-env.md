# Values per Environment — Basa

## Objetivo

Estrutura e defaults dos arquivos `values-oci-{dev,staging,prod}.yaml` a
serem criados em `k8s/helm/gateway/` quando Fase 03 for executada.

## Localização dos arquivos

```
k8s/helm/gateway/
├── values.yaml                      # defaults neutros (cloud-agnostic)
├── values-gcp-dev.yaml              # já existente
├── values-gcp-staging.yaml          # já existente
├── values-gcp-production.yaml       # já existente
├── values-oci-dev.yaml              # NOVO
├── values-oci-staging.yaml          # NOVO
└── values-oci-production.yaml       # NOVO
```

## Bloco comum a todos `values-oci-*.yaml`

```yaml
cloud: oci-basa

openshift:
  enabled: true
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
    # staging em dev, prod em staging/production
  duration: 2160h           # 90d
  renewBefore: 360h         # 15d

managedCertificate:
  enabled: false            # OBRIGATÓRIO false em Basa

ingress:
  enabled: false            # OBRIGATÓRIO false em Basa

backendConfig:
  enabled: false            # OBRIGATÓRIO false em Basa

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

## `values-oci-dev.yaml`

```yaml
{{/* herda comum */}}

image:
  repository: gru.ocir.io/revenutech/gateway-basa-dev/gateway
  tag: dev-latest
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
  enabled: false            # dev: tolera down total

openshift:
  route:
    host: gateway.dev.oci.allenty.io

certManager:
  issuerRef:
    name: letsencrypt-staging     # evita rate-limit LE
  commonName: gateway.dev.oci.allenty.io
  dnsNames:
    - gateway.dev.oci.allenty.io

krakend:
  env: dev

networkPolicy:
  backends:
    - namespace: ledgeros-dev
      app: ledgeros
      port: 8081
    - namespace: paymentos-dev
      app: paymentos
      port: 8082
    - namespace: identos-dev
      app: identos
      port: 8091
    - namespace: atmos-dev
      app: atmos
      port: 8088

prometheusRule:
  enabled: false             # dev: ruído alto, sem on-call
```

## `values-oci-staging.yaml`

```yaml
image:
  repository: gru.ocir.io/revenutech/gateway-basa-staging/gateway
  tag: staging-latest
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
    host: gateway.staging.oci.allenty.io

certManager:
  issuerRef:
    name: letsencrypt-prod
  commonName: gateway.staging.oci.allenty.io
  dnsNames:
    - gateway.staging.oci.allenty.io

krakend:
  env: staging

networkPolicy:
  backends:
    - namespace: ledgeros-staging
      app: ledgeros
      port: 8081
    - namespace: paymentos-staging
      app: paymentos
      port: 8082
    - namespace: identos-staging
      app: identos
      port: 8091
    - namespace: atmos-staging
      app: atmos
      port: 8088
```

## `values-oci-production.yaml`

```yaml
image:
  repository: gru.ocir.io/revenutech/gateway-basa-prod/gateway
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
  env: prod

networkPolicy:
  backends:
    - namespace: ledgeros-production
      app: ledgeros
      port: 8081
    - namespace: paymentos-production
      app: paymentos
      port: 8082
    - namespace: identos-production
      app: identos
      port: 8091
    - namespace: atmos-production
      app: atmos
      port: 8088

prometheusRule:
  enabled: true

# Annotations extras em prod
annotations:
  platform.revenu/change-ticket: ""  # setado pelo pipeline
```

## Variáveis setadas no pipeline (override `--set`)

- `image.tag` — SHA do commit (`dev-abc123`) ou tag (`v1.0.0`).
- `configHash` — SHA do config compilado.
- `annotations.platform\.revenu/change-ticket` — ID do PR/ticket (prod).

## Diferenças sintéticas dev → staging → prod

| Atributo | dev | staging | prod |
|---|---|---|---|
| Replicas iniciais | 1 | 2 | 3 |
| CPU req | 100m | 250m | 500m |
| Memory req | 64Mi | 128Mi | 256Mi |
| HPA max | 3 | 6 | 10 |
| PDB | — | maxUnavail 1 | minAvail 2 |
| LE issuer | staging | prod | prod |
| Image pull | Always | Always | IfNotPresent |
| PrometheusRule | off | on | on |
| Change ticket annotation | n/a | n/a | obrigatório |

## Validação

```
for env in dev staging production; do
  helm lint k8s/helm/gateway -f k8s/helm/gateway/values-oci-${env}.yaml
  helm template gateway k8s/helm/gateway -f k8s/helm/gateway/values-oci-${env}.yaml \
    | kubeconform -strict -schema-location default -schema-location 'https://raw.githubusercontent.com/.../openshift-json-schema/master/{{.ResourceKind}}-{{.ResourceAPIVersion}}.json'
done
```

## Checklist pronto-para-código

- [ ] 3 arquivos `values-oci-*.yaml` criados.
- [ ] `helm lint` passa em cada um.
- [ ] `helm template` renderiza sem Ingress/BackendConfig/ManagedCertificate.
- [ ] `helm template` renderiza Route + Certificate + Deployment sem
      `runAsUser` fixo.
- [ ] Backends do NetworkPolicy refletem realidade de cada env.
- [ ] Prod com PDB `minAvailable: 2` e HPA `max: 10`.
