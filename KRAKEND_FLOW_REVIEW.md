# KrakenD Flow Review

## Escopo

Analisei o fluxo configurado neste repositório a partir dos arquivos ativos de:

- `krakend/krakend.tmpl`
- `krakend/settings/*.json`
- `krakend/endpoints/*.json`
- `k8s/manifests/*.yaml`
- `k8s/policies/*.yaml`

Esta revisão é estática. Não houve execução do gateway nem testes de tráfego.

## Fluxo Geral

```text
Cliente
  -> NGINX Ingress
  -> Service krakend:8080
  -> KrakenD router
     -> CORS + security headers + telemetry globais
     -> JWT validation
     -> propagate_claims -> X-User-ID / X-Tenant-ID / X-Roles / X-JWT-JTI / X-Subscription-Tier
     -> RBAC por endpoint
     -> rate limit local por X-Tenant-ID (somente parte das rotas)
     -> proxy backend
        -> HTTP direto para módulos internos
        -> ou Envoy sidecar :8085 para REST -> gRPC
        -> ou fan-out concorrente para múltiplos backends
     -> circuit breaker por backend
     -> resposta ao cliente
```

## Arquivos-Chave

- Template raiz: `krakend/krakend.tmpl`
- JWT e propagação de claims: `krakend/partials/jwt_validator.tmpl`
- Rate limit atual: `krakend/partials/rate_limiter.tmpl`
- Circuit breaker: `krakend/partials/circuit_breaker.tmpl`
- Telemetria e métricas: `krakend/partials/telemetry.tmpl`
- Deploy com 2 réplicas e sidecar Envoy: `k8s/manifests/deployment.yaml`

## Matriz de Rotas Ativas

Considerei apenas os endpoints efetivamente incluídos em `krakend/krakend.tmpl`.
Os arquivos em `krakend/endpoints/ledgeros/*.json` existem, mas não entram no template principal.

| Grupo | Métodos | Entrada -> Backend | Auth/RBAC | Rate limit | Observações |
|---|---|---|---|---|---|
| Health | `GET` | `/__health` e `/__ready` | sem JWT | não | `/__ready` depende do `ledgeros_http`; `/__health` é redundante porque o KrakenD já expõe esse endpoint nativamente |
| Ledger HTTP | `POST`,`GET` | `/v1/postings`, `/v1/postings/{id}`, `/v1/balances/{id}`, `/v1/settlements`, `/v1/reconciliation/jobs` | JWT + RBAC por role | sim | proxy HTTP direto para `ledgeros_http`; circuit breaker `cb_posting` |
| Ledger gRPC | `POST`,`GET` | `/grpc/v1/*` | JWT + RBAC por role | sim | vai para Envoy em `127.0.0.1:8085` no K8s e depois gRPC |
| Ledger dinâmico | `GET` | `/v1/my/postings`, `/v1/my/balances`, `/v1/my/dashboard` | JWT + RBAC | parcial | usa `{JWT.tenant_id}` e `{JWT.sub}` no `url_pattern`; `/v1/my/dashboard` agrega Ledger + PaymentOS |
| Dashboard agregado | `GET` | `/v1/dashboard/overview`, `/v1/dashboard/health` | JWT + RBAC | não | fan-out para 4 ou 5 backends; `overview` usa `concurrent_calls` |
| PaymentOS | `POST`,`GET` | `/v1/pix/{path}`, `/v1/ted/{path}`, `/v1/boleto/{path}` | JWT + RBAC | não | `no-op`; usa `/{path}` como se fosse wildcard |
| Atmos | `POST`,`GET` | `/v1/atm/{path}` | JWT + RBAC | não | `no-op`; usa `/{path}` |
| Identos | `POST`,`GET` | `/v1/auth/{path}`, `/v1/users/{path}` | `/v1/auth/*`: JWT sem roles; `/v1/users/*`: JWT + `ledger-admin` | não | revisar se `/v1/auth/*` deveria mesmo exigir token |
| Admin | `GET`,`POST` | `/v1/admin/{path}` | JWT + `ledger-admin` | não | `no-op`; usa `/{path}` |
| OnboardOS | `POST`,`GET` | `/v1/onboarding/{path}` | JWT + RBAC | não | `no-op`; usa `/{path}` |
| AccountOS | `POST`,`GET`,`PUT` | `/v1/accounts/{path}` | JWT + RBAC | não | `no-op`; usa `/{path}` |
| FinanceOS | `POST`,`GET` | `/v1/finance/{path}` | JWT + RBAC | não | `no-op`; usa `/{path}` |

## Controles Ativos no Fluxo

### Globais

- OpenTelemetry e métricas em `:8090`
- CORS por ambiente
- Security headers HTTP
- Logging em stdout

### Por endpoint

- JWT validation
- Propagação de claims para headers
- RBAC em quase todas as rotas protegidas
- Circuit breaker por backend
- Rate limit local apenas nas rotas de Ledger HTTP, Ledger gRPC e parte do fluxo dinâmico

## Controles Existentes Mas Desconectados

Os arquivos abaixo existem, mas não estão conectados ao fluxo ativo principal:

- `krakend/partials/api_key_validator.tmpl`
- `krakend/partials/token_revocation.tmpl`
- `krakend/partials/security_policies.tmpl`
- `krakend/partials/redis_rate_limiter.tmpl`
- `krakend/partials/rate_limiter_tiered.tmpl`
- `krakend/partials/mtls_backend.tmpl`
- `krakend/partials/json_schema_validator.tmpl`
- `krakend/partials/response_cache.tmpl`
- `krakend/partials/business_metrics.tmpl`
- `krakend/partials/access_log.tmpl`
- `krakend/partials/audit_evidence.tmpl`
- `krakend/partials/web_filter.tmpl`

## Achados Principais

### 1. Egress de Keycloak parece desalinhado com JWKS de staging/prod

Em `staging` e `prod`, o JWKS aponta para URLs externas:

- `krakend/settings/staging.json`
- `krakend/settings/prod.json`

Mas a NetworkPolicy libera Keycloak apenas por `namespaceSelector` e `podSelector` internos:

- `k8s/policies/krakend-egress.yaml`

Se o JWKS for realmente externo, a validação JWT pode falhar no cluster.

### 2. Rate limit atual é local por instância

O deployment sobe 2 réplicas:

- `k8s/manifests/deployment.yaml`

O partial ativo usa `qos/ratelimit/router`:

- `krakend/partials/rate_limiter.tmpl`

Isso indica rate limit por instância, não distribuído. Já existe um rate limit Redis distribuído no repo:

- `krakend/partials/redis_rate_limiter.tmpl`

Mas ele não está conectado ao fluxo principal.

### 3. Rotas vendidas como wildcard não usam a feature oficial de wildcard

Vários arquivos descrevem equivalência com wildcard enterprise, mas implementam:

- `/v1/accounts/{path}`
- `/v1/onboarding/{path}`
- `/v1/finance/{path}`
- `/v1/pix/{path}`

Isso não equivale ao wildcard oficial `/*`. Há risco funcional se a intenção for encaminhar subcaminhos arbitrários.

### 4. mTLS está preparado, mas não ativo

O pod monta certificados:

- `k8s/manifests/deployment.yaml`

E há partial de client TLS:

- `krakend/partials/mtls_backend.tmpl`

Mas os backends ativos em `staging` e `prod` seguem como `http://...`, e o partial TLS não entra no fluxo.

### 5. ConfigMap base está vazio

O manifest base:

- `k8s/manifests/configmap.yaml`

tem `data: {}`. O repo depende de CI/CD ou `configMapGenerator` para empacotar a config real do KrakenD.

### 6. `service_routes.json` parece arquivo morto

Há documentação citando:

- `krakend/settings/service_routes.json`

Mas não encontrei uso desse arquivo no runtime ativo.

## Observações Adicionais

- `POST /v1/auth/{path}` exige JWT. Se essa rota inclui login ou emissão de token, o desenho precisa ser revisto.
- `__health` já existe nativamente no KrakenD. A definição explícita no repo parece redundante.
- Os arquivos em `krakend/endpoints/ledgeros/*.json` parecem migrações parciais ou material legado; não são incluídos em `krakend/krakend.tmpl`.

## Referências Oficiais

- Health endpoint: `https://www.krakend.io/docs/service-settings/health/`
- Wildcard endpoints: `https://www.krakend.io/docs/enterprise/endpoints/wildcard/`

## Próximos Passos Recomendados

1. Corrigir as rotas `/{path}` para wildcard real ou trocar por rotas explícitas.
2. Aplicar rate limit distribuído com Redis nas rotas hoje sem proteção.
3. Resolver o desalinhamento entre JWKS externo e NetworkPolicy.
4. Conectar controles já preparados no repo: token revocation, API key, security policies e mTLS.
