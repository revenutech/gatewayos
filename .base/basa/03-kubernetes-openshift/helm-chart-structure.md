# Helm Chart Structure

## Objetivo

Definir como o chart Helm existente (`k8s/helm/gateway/`) acomoda o track
Basa **sem fork**, via templates condicionais e valores por cloud.

## Decisão — chart único

Manter **um único chart** `k8s/helm/gateway/`, ampliando com:

- Novos templates condicionais (Route, Certificate, SCC).
- Bloco `openshift` em `values.yaml` (disabled por default).
- Bloco `certManager` (alternativo a `managedCertificate`).

Rejeitado: chart separado `gateway-oci`. Motivo: divergência entre charts
esconde regressões; manter paridade pressiona paridade de comportamento.

## Valores novos em `values.yaml`

```yaml
# Cloud / plataforma
cloud: gcp              # gcp | oci (usado para pull secret, labels)

openshift:
  enabled: false        # true em values-oci-*.yaml
  scc:
    create: false       # criar SCC custom (senão usa restricted-v2)
    name: ""
  route:
    enabled: true
    host: ""            # gateway.dev.oci.allenty.io
    tlsTermination: edge    # edge | passthrough | reencrypt
    insecureEdgeTerminationPolicy: Redirect
    wildcardPolicy: None

certManager:
  enabled: false        # true em values-oci-*.yaml
  issuerRef:
    kind: ClusterIssuer
    name: letsencrypt-prod    # staging em dev
  dnsNames: []
  commonName: ""
  duration: 2160h       # 90d
  renewBefore: 360h     # 15d

# Já existentes (recapitulados)
managedCertificate:
  enabled: false        # true em values-gcp-*.yaml
  domains: []

ingress:
  enabled: false        # true em values-gcp-*.yaml

image:
  repository: devopsfaith/krakend     # override em Basa: gru.ocir.io/.../gateway
  tag: "2.9.4"
  pullSecret: ""                       # nome do pull secret em OCP
```

## Novos templates

| Arquivo | Renderização condicional |
|---|---|
| `templates/route.yaml` | `{{- if and .Values.openshift.enabled .Values.openshift.route.enabled }}` |
| `templates/certificate.yaml` | `{{- if .Values.certManager.enabled }}` |
| `templates/scc.yaml` | `{{- if and .Values.openshift.enabled .Values.openshift.scc.create }}` |
| `templates/image-pull-secret-job.yaml` | (opcional) Helm hook que lê OCI Vault via ExternalSecret |

## Templates existentes — ajustes

### `deployment.yaml`

Adicionar, sob `{{- if .Values.openshift.enabled }}`:

- Remover `runAsUser`/`runAsGroup` do `securityContext` (deixar OpenShift
  atribuir UID random via SCC).
- Manter `readOnlyRootFilesystem: true`, `allowPrivilegeEscalation: false`,
  `capabilities.drop: ["ALL"]`, `seccompProfile.type: RuntimeDefault`.
- `image.repository` aceita OCIR URL completo.
- `imagePullSecrets` renderiza `{{ .Values.image.pullSecret }}` se setado.

### `ingress.yaml`

Manter como está. Renderiza apenas se `ingress.enabled: true` (GCP).

### `service.yaml`, `serviceaccount.yaml`, `hpa.yaml`, `pdb.yaml`, `servicemonitor.yaml`, `networkpolicy.yaml`

**Sem mudança** — compatíveis com OpenShift.

### `managed-certificate.yaml`

Renderiza só se `managedCertificate.enabled: true` (GCP). Basa não usa.

## Labels padrão

```
app.kubernetes.io/name: gateway
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/version: {{ .Chart.AppVersion }}
app.kubernetes.io/component: api-gateway
app.kubernetes.io/part-of: revenu-platform
app.kubernetes.io/managed-by: Helm
platform.revenu/track: {{ .Values.cloud | default "gcp" }}       # gcp ou oci-basa
platform.revenu/env: {{ .Values.krakend.env }}
platform.revenu/iso27001: "true"
```

## Pull secrets

Em OCP, imagem pull de OCIR exige `dockerconfigjson` secret. Fluxo:

1. **Terraform / OCIR** gera token CI temporário (Fase 02).
2. **External Secrets Operator** sincroniza de OCI Vault → Secret K8s
   `ocir-pull` no namespace `gateway-{env}`.
3. **Helm chart** referencia `imagePullSecrets: [ name: ocir-pull ]`
   quando `image.pullSecret: ocir-pull`.

Alternativa: criar **Project-level pull secret** via `oc secrets link
default ocir-pull --for=pull` (fora do chart; runbook).

## Como renderizar

```
# Dev (Basa)
helm template gateway k8s/helm/gateway \
  -f k8s/helm/gateway/values-oci-dev.yaml \
  -n gateway-dev

# Dev (GCP) — continua idêntico
helm template gateway k8s/helm/gateway \
  -f k8s/helm/gateway/values-gcp-dev.yaml
```

## Validação

CI (Fase 06) valida via:

```
helm lint k8s/helm/gateway
helm template gateway k8s/helm/gateway -f k8s/helm/gateway/values-oci-dev.yaml | kubeval --strict
helm template gateway k8s/helm/gateway -f k8s/helm/gateway/values-oci-prod.yaml | kubeconform -strict -schema-location default
```

## Checklist pronto-para-código

- [ ] Novos blocos em `values.yaml` (disabled por default).
- [ ] 3 novos templates condicionais criados.
- [ ] `values-oci-{dev,staging,prod}.yaml` compostos (ver
      `values-per-env.md`).
- [ ] `helm lint` passa.
- [ ] `helm template` renderiza Route + Certificate + Deployment sem
      `runAsUser` fixo em Basa.
- [ ] Render GCP continua idêntico ao atual.
