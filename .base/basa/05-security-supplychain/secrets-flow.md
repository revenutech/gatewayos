# Secrets Flow — OCI Vault → ESO → Kubernetes Secret

## Objetivo

Especificar como secrets (pull tokens, JWKS overrides, webhook URLs,
admin passwords) chegam aos pods sem nunca aparecer em git, Helm values
ou env vars do workflow. Baseado em **External Secrets Operator (ESO)**
com provider OCI.

## Componentes

| Item | Tecnologia |
|---|---|
| Secret store | OCI Vault |
| Sincronizador | External Secrets Operator (ESO) |
| Auth | Resource Principal (pod SA → dynamic group) |
| Rotação | ESO `refreshInterval` + rotação no Vault |
| Consumo em K8s | Kubernetes Secret regular (gerado por ESO) |

## Fluxo

```
OCI Vault (secret: gateway-pro/ocir-pull)
         │
         │ API call (Resource Principal)
         ▼
External Secrets Operator (namespace: external-secrets)
         │ watch: ExternalSecret CR
         ▼
Kubernetes Secret (ocir-pull em gateway-pro)
         │
         ▼
Pod do Gateway (imagePullSecrets, envFrom)
```

## Instalação do ESO

Via OperatorHub (community operators):

```yaml
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: external-secrets-operator
  namespace: external-secrets
spec:
  channel: stable
  name: external-secrets-operator
  source: community-operators
```

Alternativa: Helm chart oficial `external-secrets/external-secrets`.

## Provider OCI

ESO tem provider `oracle` (OCI Vault). Requer:
- OCI config com Resource Principal (auto em pod com dynamic group match).
- Namespace + region + vault OCID.

## ClusterSecretStore

```yaml
apiVersion: external-secrets.io/v1beta1
kind: ClusterSecretStore
metadata:
  name: oci-vault-{env}
spec:
  provider:
    oracle:
      region: sa-saopaulo-1
      vault: ocid1.vault.oc1.sa-saopaulo-1.xxxxx         # output de Fase 02
      auth:
        secretRef:
          # Se não estiver usando Resource Principal:
          # referenciar Secret com OCI keys (não recomendado)
        # Preferido: Resource Principal via annotation
      principalType: InstancePrincipal                    # ou ResourcePrincipal
      compartment: ocid1.compartment.oc1..xxxx
```

ServiceAccount do ESO deve estar em **dynamic group** com policy:

```
Allow dynamic-group eso-gateway-basa-{env}-dg to read secret-family in compartment id <gateway-basa-{env}>
```

## ExternalSecret — pull secret OCIR

```yaml
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: ocir-pull
  namespace: gateway-{env}
spec:
  refreshInterval: 1h
  secretStoreRef:
    kind: ClusterSecretStore
    name: oci-vault-{env}
  target:
    name: ocir-pull
    template:
      type: kubernetes.io/dockerconfigjson
      data:
        .dockerconfigjson: |
          {
            "auths": {
              "gru.ocir.io": {
                "auth": "{{ .dockerconfigAuth | b64enc }}",
                "email": "bot@revenu.com.br"
              }
            }
          }
  data:
    - secretKey: dockerconfigAuth
      remoteRef:
        key: gateway-{env}/ocir-pull-token
        # value: "<tenancy-namespace>/<user>:<auth-token>" (base64 automático)
```

## ExternalSecret — JWKS URL override (opcional)

```yaml
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: gateway-env
  namespace: gateway-{env}
spec:
  refreshInterval: 15m
  secretStoreRef:
    kind: ClusterSecretStore
    name: oci-vault-{env}
  target:
    name: gateway-env
    template:
      data:
        JWKS_URL: "{{ .jwks_url }}"
        RATE_LIMIT_REDIS_PASSWORD: "{{ .redis_password }}"
  data:
    - secretKey: jwks_url
      remoteRef:
        key: gateway-{env}/jwks_url
    - secretKey: redis_password
      remoteRef:
        key: gateway-{env}/redis_password
```

Deployment consome via:

```yaml
envFrom:
  - secretRef:
      name: gateway-env
```

## ExternalSecret — Slack webhook

```yaml
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: slack-webhook
  namespace: gateway-observability
spec:
  refreshInterval: 24h
  secretStoreRef:
    kind: ClusterSecretStore
    name: oci-vault-pro
  target:
    name: slack-webhook
  data:
    - secretKey: url
      remoteRef:
        key: platform/slack/gateway-alerts-webhook
```

Consumido pelo Alertmanager (Fase 04).

## ExternalSecret — Grafana admin password

Já referenciado em Fase 04. Refresh 30d, rotação manual por runbook.

## Rotação

| Secret | Frequência | Gatilho |
|---|---|---|
| OCIR pull token | 30d | cronjob CI gera novo token, atualiza Vault, ESO puxa em 1h |
| JWKS URL | change only | Keycloak URL é estável |
| Redis password | 90d | runbook |
| Grafana admin | 90d | runbook |
| Slack webhook | on-demand | revoke + regenerate em Slack, atualizar Vault |

Rotação do **Vault side** → ESO detecta em `refreshInterval` e atualiza
Secret K8s → pods veem novo valor no próximo reload.

**Reload automático** — Fase 03 já referencia `configHash` (checksum do
config/Secret) via annotation do Deployment template, forçando rollout
quando Secret muda.

## Segurança do ESO

- **RBAC** restrito: ESO SA não pode ler Secrets de outros namespaces
  (além dos targets declarados).
- **Network policy**: ESO só conversa com OCI Vault endpoint + kube-api.
- **Audit log**: OCI Vault logs gravam quem leu cada secret e quando
  (A.8.15).

## Emergência / break-glass

Se ESO falhar (Vault API down, operator crash), pods podem:
1. Cache local do último valor (`kubernetes.io/managed-by: eso` não
   impede leitura).
2. Override manual via `kubectl create secret` (registra em runbook).
3. Emergency secret rotation documentada em Fase 08.

## Alternativa — Secrets Store CSI Driver + OCI provider

Vantagens:
- Secret **não persiste como Kubernetes Secret** — volume montado por pod.
- Menor superfície de leak em etcd.

Desvantagens:
- Config por pod (mais verboso que ExternalSecret).
- Menos maduro o provider OCI (abril 2026).

**V1 adota ESO.** CSI fica ADR futuro se ameaça de leak em etcd materializar.

## Decisões de design

1. **ESO, não CSI Driver** — maturidade + DX.
2. **ClusterSecretStore por env** — um Vault, uma CSS.
3. **Resource Principal** (InstancePrincipal) — sem keys estáticas.
4. **Refresh 1h default** — baixo custo, rotação rápida.
5. **Template para compor dockerconfigjson** — evita ter secret pré-formatado em Vault.
6. **configHash annotation** no Deployment para rollout auto ao mudar Secret.

## Controles ISO 27001

- A.5.17 — Authentication information.
- A.8.2 — Privileged access rights.
- A.8.5 — Secure authentication.
- A.8.15 — Logging (audit do Vault).
- A.8.24 — Use of cryptography (secrets at rest no Vault).

## Checklist pronto-para-código

- [ ] ESO instalado e `ClusterSecretStore` por env configurada.
- [ ] Dynamic group + policy na OCI permite ESO ler Vault.
- [ ] `ExternalSecret` para `ocir-pull` em cada namespace `gateway-*`.
- [ ] `ExternalSecret` para env vars (JWKS, Redis).
- [ ] `ExternalSecret` para Grafana admin, Slack webhook, etc.
- [ ] Rotação de OCIR token via cronjob documentada.
- [ ] `configHash` annotation no Deployment template.
- [ ] Audit do Vault visível em OCI Console.
