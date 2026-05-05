# Correção do Keycloak Base Path no Gateway

## Problema

O gateway KrakenD não conseguia rotear requests para endpoints do Keycloak (token, certs, userinfo, etc.) porque havia uma incompatibilidade entre o path externo e o path interno do backend.

**Erro observado:**
```json
{"error":"Unable to find matching target resource method"}
```

**Causa raiz:**
O template `endpoint_keycloak_v1.tmpl` usava path fixo `/auth/realms/...` no `url_pattern` do backend, mas dependendo da versão/configuração do Keycloak, o path interno pode ou não ter o prefixo `/auth`.

## Versões do Keycloak por Ambiente

| Ambiente | Versão | Postgres | Path Interno |
|----------|--------|----------|--------------|
| UAT | 26.0.5 | 15 | `/auth/realms/...` (após reconfiguração) |
| SQA | 26.5.3 | 16-alpine | `/auth/realms/...` |
| SIT | 26.x | 16-alpine | `/auth/realms/...` |

**Nota sobre versões:**
- Keycloak 17+ removeu `/auth` do path padrão
- Para manter compatibilidade, usa-se `KC_HTTP_RELATIVE_PATH=/auth`
- Todos os ambientes BASA usam `/auth` para padronização

## Solução Implementada

### 1. Variável `keycloak_base_path`

Adicionada variável `keycloak_base_path` nos arquivos de configuração de cada ambiente:

**Arquivos modificados:**
- `krakend/settings/uat/keycloak.json`
- `krakend/settings/sqa/keycloak.json`
- `krakend/settings/sit/keycloak.json`
- `krakend/settings/sqa.json` (all-in-one)
- `krakend/settings/sit.json` (all-in-one)

**Configuração padrão para todos os ambientes BASA:**
```json
{
  "jwks_url": "http://keycloak.keycloak.svc.clusterset.local:8080/auth/realms/ledgeros/protocol/openid-connect/certs",
  "issuer": "https://{env}.corebanxapp.com.br/auth/realms/ledgeros",
  "audience": "account",
  "disable_jwk_security": true,
  "keycloak_base_path": "/auth"
}
```

### 2. Template Atualizado

O template `krakend/templates/endpoint_keycloak_v1.tmpl` foi modificado para usar a variável:

```
url_pattern": "{{ .keycloak_base_path }}/realms/ledgeros/protocol/openid-connect/token"
```

**Endpoints afetados:**
- `/.well-known/openid-configuration`
- `/protocol/openid-connect/certs`
- `/protocol/openid-connect/token`
- `/protocol/openid-connect/auth`
- `/protocol/openid-connect/userinfo`
- `/protocol/openid-connect/logout` (GET e POST)
- `/protocol/openid-connect/token/introspect`

### 3. Fluxo de Tradução de Path

```
Request Externo                    Backend Keycloak
─────────────────────────────────────────────────────
POST /auth/realms/ledgeros/...  →  POST /auth/realms/ledgeros/...
     (URL pública)                      (via MCS clusterset.local)
```

## Pré-requisito: Configuração do Keycloak

Para que esta correção funcione, o Keycloak de cada ambiente deve estar configurado com:

```yaml
env:
  - name: KC_HTTP_RELATIVE_PATH
    value: "/auth"
```

### Verificar configuração atual:

```bash
# UAT
kubectl --context gke_revenu-gateway-uat_southamerica-east1-a_gateway-uat \
  get deployment keycloak -n keycloak -o jsonpath='{.spec.template.spec.containers[0].env}' | jq

# SQA
kubectl --context gke_revenu-gateway-sqa_southamerica-east1-a_keycloak-sqa \
  get statefulset keycloak -n keycloak -o jsonpath='{.spec.template.spec.containers[0].env}' | jq
```

### Aplicar configuração (se necessário):

```bash
kubectl patch deployment keycloak -n keycloak --type='json' -p='[
  {"op": "add", "path": "/spec/template/spec/containers/0/env/-", "value": {"name": "KC_HTTP_RELATIVE_PATH", "value": "/auth"}}
]'
```

## Aplicação Manual

### 1. Validar configuração do KrakenD

```bash
docker run --rm \
  -v ./krakend:/etc/krakend \
  -e FC_ENABLE=1 \
  -e FC_SETTINGS=/etc/krakend/settings/uat \
  -e FC_PARTIALS=/etc/krakend/partials \
  -e FC_TEMPLATES=/etc/krakend/templates \
  devopsfaith/krakend:2.9.4 \
  check -c /etc/krakend/krakend.tmpl
```

### 2. Aplicar no cluster

```bash
# UAT
kubectl --context gke_revenu-gateway-uat_southamerica-east1-a_gateway-uat \
  rollout restart deployment gateway

# SQA
kubectl --context gke_revenu-gateway-sqa_southamerica-east1-a_gateway-sqa \
  rollout restart deployment gateway
```

### 3. Testar endpoint de token

```bash
# Obter token via endpoint externo
curl -X POST "https://uat.corebanxapp.com.br/auth/realms/ledgeros/protocol/openid-connect/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "grant_type=client_credentials" \
  -d "client_id=paymentos" \
  -d "client_secret=YOUR_SECRET"
```

## Aplicação via Workflow

Os workflows de CD aplicam automaticamente ao fazer merge/push:

| Ambiente | Branch | Workflow |
|----------|--------|----------|
| UAT | `main` | `.github/workflows/cd-uat-gcp.yml` |
| SQA | `main` | `.github/workflows/cd-sqa-gcp.yml` |
| SIT | `stage` | `.github/workflows/cd-sit-gcp.yml` |

O deploy usa Helm com os values específicos de cada ambiente:
```bash
helm upgrade --install gateway k8s/helm/gateway \
  -f k8s/helm/gateway/values-gcp-{env}.yaml \
  --set image.tag={env}-${{ github.sha }}
```

## Pontos de Atenção

### 1. Keycloak de UAT - AÇÃO NECESSÁRIA

O Keycloak de UAT (v26.0.5) estava originalmente SEM `/auth`. É necessário adicionar `KC_HTTP_RELATIVE_PATH=/auth` para padronizar com SQA e SIT.

**Verificar configuração atual:**
```bash
kubectl --context gke_revenu-gateway-uat_southamerica-east1-a_gateway-uat \
  get deployment keycloak -n keycloak \
  -o jsonpath='{.spec.template.spec.containers[0].env[?(@.name=="KC_HTTP_RELATIVE_PATH")].value}'
```

**Se estiver vazio, aplicar:**
```bash
kubectl --context gke_revenu-gateway-uat_southamerica-east1-a_gateway-uat \
  patch deployment keycloak -n keycloak --type='json' \
  -p='[{"op": "add", "path": "/spec/template/spec/containers/0/env/-", "value": {"name": "KC_HTTP_RELATIVE_PATH", "value": "/auth"}}]'
```

### 2. Arquivos de Configuração Duplicados

Existem dois formatos de configuração:
- **Diretórios** (`settings/uat/`, `settings/sqa/`, `settings/sit/`): Usados pelo Helm com `fcSettings`
- **Arquivos raiz** (`settings/sqa.json`, `settings/sit.json`): Configuração all-in-one

Ambos foram atualizados, mas ao fazer mudanças futuras, lembre-se de atualizar os dois.

### 3. MCS (Multi-Cluster Services)

O backend do Keycloak usa MCS para comunicação cross-cluster:
```
http://keycloak.keycloak.svc.clusterset.local:8080
```

Certifique-se de que:
- Os clusters estão no mesmo GKE Fleet
- O ServiceExport existe no cluster do Keycloak
- O ServiceImport existe no cluster do Gateway

### 4. Paymentos também usa AUTH_JWKS_ENDPOINT

O arquivo `paymentos/k8s/helm/paymentos/values-gateway-uat.yaml` também foi atualizado para usar `/auth`:

```yaml
AUTH_JWKS_ENDPOINT: "http://keycloak.keycloak.svc.clusterset.local:8080/auth/realms/ledgeros/protocol/openid-connect/certs"
```

## Arquivos Modificados

### Gateway

| Arquivo | Mudança |
|---------|---------|
| `krakend/templates/endpoint_keycloak_v1.tmpl` | `url_pattern` usa `{{ .keycloak_base_path }}` |
| `krakend/settings/uat/keycloak.json` | `keycloak_base_path: "/auth"` |
| `krakend/settings/sqa/keycloak.json` | `keycloak_base_path: "/auth"` |
| `krakend/settings/sit/keycloak.json` | `keycloak_base_path: "/auth"` |
| `krakend/settings/sqa.json` | `keycloak_base_path: "/auth"` |
| `krakend/settings/sit.json` | `keycloak_base_path: "/auth"`, backends MCS |

### Paymentos

| Arquivo | Mudança |
|---------|---------|
| `k8s/helm/paymentos/values-gateway-uat.yaml` | `AUTH_JWKS_ENDPOINT` com `/auth` |

## Relacionados

- [CORRECAO-JWKS-MCS.md](../CORRECAO-JWKS-MCS.md) - Correção do JWKS via MCS
- [FLUXO-UAT-JDPI.md](../FLUXO-UAT-JDPI.md) - Fluxo de teste PIX/JDPI
