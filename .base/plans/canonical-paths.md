# Path Canônico — Exposição Externa da Revenu Platform

**Arquiteto Principal:** Gustavo Armoa

> Contrato canônico de exposição externa da plataforma. **Este diretório contém
> apenas documentação.** As definições de rota vivem em `krakend/endpoints/`,
> o service map em `krakend/settings/service_routes.json` e os manifests em
> `k8s/`. Este documento é a fonte de verdade sobre *qual* path é canônico,
> não sobre como está implementado hoje.

---

## 1. Regra

Toda exposição externa de qualquer módulo da Revenu Platform se dá **via REST
através do GatewayOS (KrakenD)**. Nenhum módulo publica ingress próprio.

Corolários:

- gRPC é **interno**. Externamente, só por transcodificação REST no gateway
  (Envoy), sob `/{módulo}/grpc/v1/*`.
- O gateway é o **único** ponto que valida JWT. Módulos confiam exclusivamente
  nos headers de contexto propagados.
- Comunicação entre módulos é **gRPC nativo**, por DNS de cluster, sem passar
  pelo gateway.

---

## 2. Hosts canônicos

A plataforma tem **três** ambientes. `uat`, `sit` e `sqa` pertencem ao trilho
BASA, que é projeto separado.

| Branch | Ambiente | Host API | Host Auth |
|---|---|---|---|
| `main` | production | `api.revenu.tech` | `auth.revenu.tech` |
| `staging` | sandbox | `sandbox.api.revenu.tech` | `sandbox.auth.revenu.tech` |
| `develop` | develop | `develop.api.revenu.tech` | `develop.auth.revenu.tech` |

`auth.*` é **host dedicado do gateway**, que proxia o KeycloakOS.

Domínios em descarte: `revenu.com.br`, `authorityos.com`, `allenty.io`,
`revenu.io`, `revenu.tech`.

Âncoras imutáveis (compiladas no binário do app iOS, versões em campo):
`api.revenu.tech`, `card|loan|insurance|onboarding.revenu.tech` e as variantes
`sandbox.*`. Não podem ser aposentadas sem janela longa de depreciação.

---

## 3. Convenção de path

```
https://api.revenu.tech/{módulo}/v1/{recurso}
```

Namespace **por módulo**. Elimina colisão — 22 prefixos `/v1/*` são disputados
por dois ou mais módulos (`/v1/payments` por três, `/v1/settlements` por três).

### Módulos do núcleo

| Path | Módulo | Backend (DNS de cluster) |
|---|---|---|
| `/identityos/v1/*` | IdentityOS — IAM | `identos:8091` |
| `/onboardos/v1/*` | OnboardOS — KYC/KYB, RIO | `onboardos:8092` |
| `/accountos/v1/*` | AccountOS — ciclo de vida de conta | `accountos:8093` |
| `/ledgeros/v1/*` | LedgerOS — razão contábil | `ledgeros:8081` |
| `/ledgeros/grpc/v1/*` | LedgerOS — transcodificação gRPC | `ledgeros:9081` via Envoy |
| `/authorityos/v1/*` | AuthorityOS — regulatório | `authorityos:8083` |
| `/paymentos/v1/*` | PaymentOS — trilhos de pagamento | `paymentos:8082` |

### Auth

`auth.revenu.tech` é host dedicado servido pelo gateway, que proxia o KeycloakOS.
Realm único: **`ledgeros`**.

```
auth.revenu.tech/realms/ledgeros/.well-known/openid-configuration
auth.revenu.tech/realms/ledgeros/protocol/openid-connect/auth
auth.revenu.tech/realms/ledgeros/protocol/openid-connect/token
auth.revenu.tech/realms/ledgeros/protocol/openid-connect/certs
auth.revenu.tech/realms/ledgeros/protocol/openid-connect/userinfo
auth.revenu.tech/realms/ledgeros/protocol/openid-connect/logout
auth.revenu.tech/realms/ledgeros/protocol/openid-connect/token/introspect
```

O `keycloak_base_path` varia por versão do Keycloak (17+ removeu `/auth`).
É variável de ambiente, não valor fixo — ver `CORRECAO-KEYCLOAK-BASE-PATH.md`.

### Reservados

| Path | Uso |
|---|---|
| `/__health`, `/__ready` | health do próprio gateway |
| `/{módulo}/__ready` | readiness por backend |

---

## 4. Contrato de contexto

O gateway valida o JWT e propaga identidade por header. **Remove** qualquer um
destes vindo do cliente, antes do roteamento — são de emissão exclusiva do gateway.

| Header | Origem (claim) |
|---|---|
| `x-user-id` | `sub` |
| `x-tenant-id` | `tenant_id` |
| `x-user-roles` | `realm_access.roles` |
| `x-user-email` | `email` |
| `x-request-id` | gerado pelo gateway |

Módulos **não** validam JWT por conta própria e **não** confiam em header de
entrada não propagado pelo gateway.

---

## 5. Não-canônico

Paths existentes que violam a regra e precisam de decisão:

| Path | Problema |
|---|---|
| `/paymentos/banklink/pix/jdpi/spi/api/v2/*` | expõe o contrato cru do provedor JDPI; acopla o público ao PSTI |
| `grpc.exchangeos.revenu.tech` | gRPC em ingress próprio |
| `grpc.onboarding.revenu.com.br` | gRPC em ingress próprio |
| `atmos` no `service_map` | módulo sem repositório em `revenu-platform` |

---

## 6. Adicionar um módulo

Processo em 6 passos (ver `CLAUDE.md`):

1. Backend em `krakend/settings/{dev,staging,prod}.json` sob `backends`
2. Circuit breaker sob `cb_{módulo}`
3. `krakend/endpoints/{módulo}_v1.json` com as rotas
4. Incluir no array de endpoints do `krakend/krakend.tmpl`
5. Regra de egress em `k8s/policies/krakend-egress.yaml`
6. Atualizar `krakend/settings/service_routes.json`

O módulo **não** ganha ingress próprio.
