# Helm Chart Structure

## Objetivo

Estruturar o chart Helm `k8s/helm/gateway/` para deploy OpenShift-flavored
com Route, SCC opcional e Certificate via cert-manager, parametrizável por
env através de `values-oci-{env}.yaml`.

## Valores em `values.yaml`

```yaml
openshift:
  scc:
    create: false       # criar SCC custom (senão usa restricted-v2)
    name: ""
  route:
    enabled: true
    host: ""            # gateway.sqa.oci.allenty.io
    tlsTermination: edge    # edge | passthrough | reencrypt
    insecureEdgeTerminationPolicy: Redirect
    wildcardPolicy: None

certManager:
  enabled: true
  issuerRef:
    kind: ClusterIssuer
    name: letsencrypt-prod    # uat em sqa
  dnsNames: []
  commonName: ""
  duration: 2160h       # 90d
  renewBefore: 360h     # 15d

image:
  repository: ""                       # gru.ocir.io/.../gateway
  tag: "2.9.4"
  pullSecret: ""                       # nome do pull secret em OCP
```

## Templates

| Arquivo | Renderização condicional |
|---|---|
| `templates/route.yaml` | `{{- if .Values.openshift.route.enabled }}` |
| `templates/certificate.yaml` | `{{- if .Values.certManager.enabled }}` |
| `templates/scc.yaml` | `{{- if .Values.openshift.scc.create }}` |
| `templates/image-pull-secret-job.yaml` | (opcional) Helm hook que lê OCI Vault via ExternalSecret |

## Templates existentes — ajustes

### `deployment.yaml`

- Não setar `runAsUser`/`runAsGroup` (SCC atribui UID random).
- Manter `readOnlyRootFilesystem: true`, `allowPrivilegeEscalation: false`,
  `capabilities.drop: ["ALL"]`, `seccompProfile.type: RuntimeDefault`.
- `image.repository` aceita OCIR URL completo.
- `imagePullSecrets` renderiza `{{ .Values.image.pullSecret }}` se setado.

### `service.yaml`, `serviceaccount.yaml`, `hpa.yaml`, `pdb.yaml`, `servicemonitor.yaml`, `networkpolicy.yaml`

Templates padrão K8s, compatíveis com OpenShift sem mudança estrutural.

## Labels padrão

```
app.kubernetes.io/name: gateway
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/version: {{ .Chart.AppVersion }}
app.kubernetes.io/component: api-gateway
app.kubernetes.io/part-of: revenu-platform
app.kubernetes.io/managed-by: Helm
platform.revenu/track: basa
platform.revenu/env: {{ .Values.krakend.env }}
platform.revenu/iso27001: "true"
```

## Pull secrets

Imagem pull de OCIR exige `dockerconfigjson` secret. Fluxo:

1. **Terraform / OCIR** gera token CI temporário (Fase 02).
2. **External Secrets Operator** sincroniza de OCI Vault → Secret K8s
   `ocir-pull` no namespace `gateway-{env}`.
3. **Helm chart** referencia `imagePullSecrets: [ name: ocir-pull ]`
   quando `image.pullSecret: ocir-pull`.

Alternativa: criar **Project-level pull secret** via `oc secrets link
default ocir-pull --for=pull` (fora do chart; runbook).

## Como renderizar

```
helm template gateway k8s/helm/gateway \
  -f k8s/helm/gateway/values-oci-sqa.yaml \
  -n gateway-sqa
```

## Validação

CI (Fase 06) valida via:

```
helm lint k8s/helm/gateway
helm template gateway k8s/helm/gateway -f k8s/helm/gateway/values-oci-sqa.yaml | kubeval --strict
helm template gateway k8s/helm/gateway -f k8s/helm/gateway/values-oci-pro.yaml | kubeconform -strict -schema-location default
```

## Checklist pronto-para-código

- [ ] Blocos `openshift` / `certManager` presentes em `values.yaml`.
- [ ] Templates `route.yaml` / `certificate.yaml` / `scc.yaml` (se
      `scc.create: true`) criados.
- [ ] `values-oci-{sqa,uat,pro}.yaml` compostos (ver
      `values-per-env.md`).
- [ ] `helm lint` passa.
- [ ] `helm template` renderiza Route + Certificate + Deployment sem
      `runAsUser` fixo.
