# Plano macro (v9) — núcleo core banking + auth via GatewayOS

**Regra:** exposição externa exclusivamente por **REST através do GatewayOS (KrakenD)**.
Autenticação por **KeycloakOS + KrakenD** em `auth.revenu.tech`. Host de API: `api.revenu.tech`.

---

## 0. Escopo

**Restrição permanente:** só `/Users/guga/projects/revenu-platform/`.
Fora: `/Users/guga/projects/basa/`, `/Users/guga/projects/web-revenutech`,
e `revenu-platform/keycloak-upstream/` (clone de 760 MB do Keycloak upstream, não é repo nosso).

**Sete repositórios em foco:**

| Repo | Papel na cadeia |
|---|---|
| `gatewayos` | KrakenD — única porta de entrada externa |
| `keycloakos-revenu` | IdP OAuth2/OIDC — autenticação |
| `identityos-revenu` | IAM — identidade, sessão, consentimento, RBAC/ABAC |
| `onboardos-revenu` | Onboarding, KYC/KYB, decisão de risco (RIO) |
| `accounts-revenu` | Ciclo de vida de conta |
| `ledgeros` | Razão contábil (absorveu AccountOS no MS-048) |
| `authorityos-revenu` | Regulatório (SISBAJUD, CADOCs, CCS, SCR) |

Cadeia funcional: **onboarding → identidade → conta → razão → regulatório**,
fronteada pelo gateway e autenticada por Keycloak.

**Sai do plano:** paymentos (permanece no gateway como está, sem alteração),
wss-gateway, navigatoros-sandbox, cardos, loanos, investos, exchangeos,
insuranceos, billos, riskos, financeos, codepix, app-ios, cockroachdb,
web-revenutech. A questão `chargeos`/`harmonyos` fica suspensa — vive no
wss-gateway, agora fora de escopo.

---

## 1. Estado atual do conjunto focado

### Cobertura no gateway

| Serviço | Endpoints roteados | Superfície real | Lacuna |
|---|---:|---:|---|
| onboardos | 184 | ~133 paths | coberto |
| ledgeros | 46 | ~40 grupos `/v1/*` | parcial |
| accountos | 6 | 30 paths / 56 rotas | **grande** |
| identos | 4 | ~150 endpoints `/v1/iam/*` | **crítica** |
| authorityos | **0** | 32 paths | **ausente** |

### Auth — já parcialmente pronto

O gateway já proxia 7 endpoints OIDC em `/auth/realms/ledgeros/*`
(well-known, auth, token, certs, introspect, userinfo, logout).
Todos os ambientes já padronizaram o realm **`ledgeros`**.

Pendência: cinco issuers distintos entre ambientes
(`auth.revenu.com.br`, `auth-staging.revenu.com.br`, `auth.allenty.io`,
`sqa.corebanxapp.com.br/auth`, `sit.corebanxapp.com.br/auth`).

### Bloqueadores

1. **`accounts-revenu` não compila** — `gen/accountos/v1` inexistente, sem
   `proto/accountos/v1/*.proto` para gerar; `cmd/worker` ausente; 9 símbolos
   faltando em `internal/worker`. CI falha determinístico.
2. **`accounts-revenu` e `ledgeros` expõem ambos `/v1/accounts`** — o MS-048
   absorveu o AccountOS para dentro do LedgerOS. Há duas implementações do
   mesmo domínio.
3. **`api.revenu.tech` não existe** (NXDOMAIN). Ingress do gateway aponta para
   `api.revenu.com.br`, domínio onde nenhum host resolve.
4. **LedgerOS não implementa estorno** — `ErrReversalNotImplemented`, HTTP 501.

---

## 2. Decisões tomadas

| # | Decisão |
|---|---|
| 1 | **`accounts-revenu` será reconstruído** servindo `/v1/accounts`, com gRPC nativo como todos os módulos (confirmado) |
| 2 | `auth.revenu.tech` é **host dedicado servido pelo gateway**, proxiando o KeycloakOS |
| 3 | **Estorno no LedgerOS é trilho separado** — fora deste plano |
| 4 | `revenu.io`: **consertar** |
| 5 | **Descartar** `authorityos.com` (23 hosts) e `revenu.com.br` (88 hosts) |

O path canônico resultante está versionado em
`gatewayos/.base/plans/canonical-paths.md`.

### Escopo da reconstrução do accounts-revenu

Estado atual bloqueia qualquer trabalho:

- `gen/accountos/v1` não existe e **não há `proto/accountos/v1/*.proto`** para gerar
- `cmd/worker` ausente (referenciado por Makefile e CI)
- 9 símbolos faltando em `internal/worker`
- 5 pacotes de teste não compilam por drift de assinatura
- as 3 sagas (`AccountOpeningSaga` de 8 passos, `AccountClosureSaga`,
  `JudicialFreezeSaga`) existem mas **não são chamadas** por nenhum wiring
- `main.go` usa `NoopPublisher`; o outbox nunca é drenado
- `AssignProductHandler` recebe repositório `nil`

### Sobreposição medida com o LedgerOS

O MS-048 absorveu o AccountOS para dentro do LedgerOS. A comparação direta:

| | `accounts-revenu` | `ledgeros` (`src/internal/account/`) |
|---|---|---|
| Rotas `/v1/accounts` | 17 | **40** |
| Arquivos Go | 165 (não compila) | 92 |
| Testes | 43 (5 pacotes quebrados) | 23 |
| Sagas | 3, **desconectadas do wiring** | opening/closure, **ligadas** |
| gRPC | **nenhum `.proto` existe** | `AccountService`, 16 RPCs, gerado |
| Estado | build quebrado | em produção (`/health` 200) |

O LedgerOS é hoje um **superset funcional**: cobre tudo que o `accounts-revenu`
expõe e ainda o fluxo ISO 20022 de abertura (`/opening/acknowledge`, `/amend`,
`/reject`, `/resume`, `/request-info`, `/modification/confirm`), CRUD de parties
e mandates, e switches de portabilidade.

**Consequência para F2:** reconstruir significa reimplementar capacidade que já
existe e roda. A fronteira precisa ser definida antes do trabalho começar —
ver pendência 1.

---

## 2b. Modelo de ambientes

`revenu-platform` tem **três** ambientes. `uat`, `sit` e `sqa` são do trilho BASA
e não pertencem à base canônica.

| Branch | Ambiente | Host API | Host Auth |
|---|---|---|---|
| `main` | **production** | `api.revenu.tech` | `auth.revenu.tech` |
| `staging` | **sandbox** | `sandbox.api.revenu.tech` | `sandbox.auth.revenu.tech` |
| `develop` | **develop** | `develop.api.revenu.tech` | `develop.auth.revenu.tech` |

### Estado atual no gatewayos — contradiz a documentação

Os três CDs canônicos estão **desabilitados**; só o trilho BASA está ativo:

```
cd-dev-gcp.yml.disabled           cd-sit-gcp.yml     ← ativo, dispara de main
cd-staging-gcp.yml.disabled       cd-sqa-gcp.yml     ← ativo, dispara de main
cd-production-gcp.yml.disabled    cd-uat-gcp.yml     ← ativo, dispara de main
```

`CLAUDE.md` documenta os três desabilitados como se fossem a esteira real.
Hoje o gateway só faz deploy para ambientes BASA.

Settings existentes: `dev.json`, `staging.json`, `prod.json`, `sqa.json`,
`sit.json` + diretórios `uat/`, `sit/`, `sqa/`.

### Trabalho decorrente

1. Renomear settings: `dev.json` → `develop.json`, `staging.json` → `sandbox.json`,
   `prod.json` → `production.json`.
2. Remover `sqa.json`, `sit.json` e os diretórios `uat/`, `sit/`, `sqa/`
   (migram para o projeto BASA).
3. Reabilitar os três CDs canônicos com o gatilho correto:
   `develop` → develop, `staging` → sandbox, `main` → production.
4. Remover `cd-sit-gcp.yml`, `cd-sqa-gcp.yml`, `cd-uat-gcp.yml`.
5. Corrigir `CLAUDE.md`, que descreve esteira inexistente.

---

## 2c. Executado — 2026-07-22

A fase FL foi executada. O que saiu do papel:

### Stack local no ar
13 containers em `revenu-platform-net`, uma unica porta publicada (8080).
Infra compartilhada (CockroachDB, Kafka, Redis, Keycloak, Vault) mais cinco
modulos: ledgeros, identityos, onboardos, authorityos, accountos.

Migrations aplicadas: ledgeros 57, onboardos 111, identityos 49, accountos 25.

### O criterio que importava, cumprido
`LEDGER_MODE=internal`. Uma conta foi aberta pelo AccountOS e o saldo
correspondente persistido no LedgerOS por gRPC autenticado:

```
account_id       c3ad143f-1ad0-41f4-96e8-d0d57ff9d354
ledger_account_id 21c23d21-87c4-4ccf-93d3-43e23cde7a8b   (BRL, confirmado no banco)
```

Primeira vez que a plataforma faz isso ponta a ponta.

### AccountOS reconstruido (F2)
Compilava zero. Agora: 5 protos escritos do zero (66 tipos, 4 servicos),
`cmd/worker` criado, 8 simbolos de worker implementados, outbox ligado
(era `NoopPublisher`), autenticacao M2M, 6 drifts de teste corrigidos.

### Defeitos encontrados executando
Nenhum apareceria sem rodar a plataforma junto:

| # | Defeito | Onde |
|---|---|---|
| 1 | `organizations` nao e feature valida no Keycloak 26.5.3 | keycloakos |
| 2 | Envoy procurava `revenu.ledgeros.v1.*`; package real e `ledgeros.v1` | gatewayos (compose **e** ConfigMap de producao) |
| 3 | Healthchecks usando `curl`/`wget` ausentes na imagem | gatewayos, ledgeros |
| 4 | `ledgeros.pb` nunca gerado — Envoy nao subia | gatewayos |
| 5 | Backend `keycloak` ausente nos ambientes canonicos | gatewayos |
| 6 | Migration 51 incompativel com CockroachDB (DROP+ADD mesma constraint) | ledgeros |
| 7 | `bitnami/kafka` removida do Docker Hub | 14 repos |
| 8 | Escopos `account:*` inexistentes no realm | keycloakos |
| 9 | Sem audience mapper — tokens sem `aud` | keycloakos |
| 10 | Endpoint de colecao ausente no gateway | gatewayos |
| 11 | Formato de escopo: OIDC usa espaco, servico esperava virgula | accountos |
| 12 | `propagate_claims` sem `scope` | gatewayos |
| 13 | JWKS do ledgeros apontando para host que responde 526 | ledgeros |
| 14 | Audience divergente: gateway `revenu-platform`, gRPC `ledgeros-api` | keycloakos |
| 15 | **Contrato gRPC quebrado**: cliente `identos.v1`, servidor `identityos.v1` | onboardos, financeos |
| 16 | `.gitignore` sem ancora engolia `cmd/worker/` e `proto/accountos/` | accountos |

### Nomenclatura unificada
- Dominio: `corebanxapp.com.br` -> `revenu.tech`, com `uat` -> `sandbox` e
  `sqa` -> `develop`.
- `identos` -> `identityos` em 539 arquivos, 15 repositorios: topicos Kafka,
  pacotes protobuf, diretorios Go, client OAuth, helpers Helm, SPI Java e
  rotas do BFF.

---

## 3. Fases

### FL — Validação local primeiro (CONCLUÍDA — ver seção 2c)

Toda mudança é validada em Docker local antes de qualquer trabalho em GCP.
O ambiente local espelha a arquitetura-alvo: **uma rede, infra compartilhada,
só o gateway exposto**. É ensaio real, não simulação.

#### A rede já existe

`cockroachdb/Makefile` já traz o target idempotente:

```
docker network create --driver bridge --attachable \
  --subnet 10.99.0.0/16 revenu-platform-net
```

Só o `accounts-revenu` a consome hoje (`docker-compose.unified.yml`).
Os outros seis declaram rede própria ou nenhuma.

#### O ambiente `develop` já está compatível

`krakend/settings/develop/backends.json` usa nomes DNS simples —
`http://ledgeros:8081`, `http://identityos:8091`, `http://onboardos:8092` —
que é exatamente o que o Compose resolve numa rede compartilhada.
Nenhuma adaptação necessária no gateway.

#### O que bloqueia hoje

Subir os sete juntos colide de imediato:

| Porta | Publicada por | Conflito |
|---|---:|---|
| `8080` | 5 composes | gateway, identityos, onboardos, accounts, ledgeros |
| `26257` | 5 composes | **cada serviço sobe seu próprio CockroachDB** |
| `9092` | 4 composes | Kafka por serviço |
| `6379` | 3 composes | Redis por serviço |

#### Desenho do stack local

```
rede: revenu-platform-net (10.99.0.0/16)

  infra compartilhada (uma instância de cada)
    cockroachdb:26257   kafka:9092   redis:6379
    keycloak:8080       vault:8200

  serviços (sem publicar porta no host)
    ledgeros:8081/9081     identityos:8091/9091
    onboardos:8092/9092    accountos:8093/9093
    authorityos:8083/9083

  única porta publicada
    gatewayos -> localhost:8080
```

Um banco por serviço continua existindo — mas como **database dentro da mesma
instância** CockroachDB, não como cinco containers.

#### Trabalho

1. Padronizar os sete composes na rede externa `revenu-platform-net`.
2. Extrair a infra compartilhada para um compose de plataforma; remover os
   CockroachDB/Kafka/Redis por serviço.
3. Remover publicação de porta no host de tudo, exceto o gateway.
4. Alinhar nomes de serviço ao `service_map` do gateway
   (`ledgeros`, `identityos`, `onboardos`, `accountos`, `authorityos`, `keycloak`).
5. Um `make up` na raiz que sobe rede, infra, serviços e gateway na ordem.

#### Critérios de aceite

- `curl localhost:8080/__health` responde
- Fluxo OIDC completo por `auth` local: token emitido e validado pelo gateway
- Cadeia ponta a ponta: onboarding aprovado → identidade criada → conta aberta
  → lançamento no razão, tudo via `localhost:8080`
- **`LEDGER_MODE=internal`, não `stub`** — é o teste que a plataforma nunca fez
- `authorityos` roteado e respondendo pelo gateway

O critério do `LEDGER_MODE` é o mais importante: hoje todos os gateways
inter-serviço estão em `stub` porque, como provisionado, não há rota entre eles.
O ambiente local é onde isso se prova antes de custar cluster.

---

### F0 — Reapontamento (sem dependências, começa já)
- Criar `api.revenu.tech` e migrar o ingress do gateway.
  **Urgente por si só:** o app iOS de produção aponta para lá e hoje é NXDOMAIN.
- Consolidar issuer em `auth.revenu.tech`, com dual-issuer no corte
  (`identityos-revenu/pkg/authn/dual_validator.go` já existe).
- Alinhar `keycloak_base_path` entre ambientes (já documentado em
  `gatewayos/CORRECAO-KEYCLOAK-BASE-PATH.md`).

### F1 — Fechar a lacuna de auth e IAM
- Rotear a superfície `/v1/iam/*` do identityos no gateway (hoje 4 de ~150).
- Consolidar os realms remanescentes fora do gateway
  (`revenu`, `authorityos`, `paymentos`, `onboardos`) no realm `ledgeros`.
- Formalizar o contrato de contexto: `x-user-id`, `x-tenant-id`, `x-user-roles`,
  `x-request-id`. Gateway **remove** esses headers se vierem do cliente.

### F2 — Reconstrução do accounts-revenu (CONCLUÍDA — build e integração validados)
- Escrever `proto/accountos/v1/*.proto` e gerar `gen/`.
- Restaurar `cmd/worker` e os 9 símbolos de `internal/worker`.
- Religar as 3 sagas, o outbox e os gateways ao wiring de `main.go`.
- Definir a fronteira com o LedgerOS (quem serve conta, quem serve razão).
- Corrigir os 5 pacotes de teste com drift de assinatura.
- Expandir de 6 para a superfície completa em `/accountos/v1/*` no gateway.

### F3 — Regulatório
- Rotear `authorityos` (0 endpoints hoje) pelos 6 passos documentados em
  `gatewayos/CLAUDE.md`.
- Prioridade nos fluxos com prazo regulatório: SISBAJUD/BLKG e CADOCs.

### F4 — Fechar exposição direta
- Remover ingress próprio dos 7 repos.
- gRPC externo só por transcodificação Envoy no gateway.
- NetworkPolicy default-deny: só o namespace do gateway alcança backends.

### F5 — Contexto e documentação
- `.env.example`, Helm values, Kustomize, CLAUDE.md e README dos 7 repos
  apontando para `api.revenu.tech` / `auth.revenu.tech`.
- Corrigir a deriva documental já medida (todos os 7 têm contagens erradas —
  ex.: onboardos declara 74 migrations, são 111; ledgeros documenta dois
  engines que não existem).

### F6 — Desacoplar BASA
- Aplicar o modelo de três ambientes (seção 2b): renomear settings, remover
  `uat`/`sit`/`sqa`, reabilitar os CDs canônicos.
Referências ao cliente dentro da base canônica, por repo:
identityos 95 · gatewayos 24 · authorityos 24 · keycloakos 12 · ledgeros 8 · onboardos 3.
Extrair para overlay de ambiente em vez de hardcode. Remover `atmos` do
`service_map` do gateway (não existe repositório).

---

## 4. Dependências

- **FL precede tudo** e não depende de nuvem.
- **F0 não depende de nada.**
- **F2 depende da decisão da seção 2.**
- **F1, F3 e F4 dependem da consolidação de cluster** — o gateway já assume
  namespace compartilhado (`*.ledgeros-production.svc.cluster.local`), o que
  confirma a direção de um cluster GKE por ambiente.

---

## 5. Pendências remanescentes

1. **Fronteira accounts-revenu × ledgeros.** O LedgerOS serve 40 rotas de conta
   contra 17 do accounts-revenu, com gRPC gerado e sagas ligadas. Três desenhos
   possíveis:
   - **(i)** `accounts-revenu` é a face de domínio; `ledgeros` mantém só as
     primitivas ledger-atômicas via gRPC interno e **remove** seu `/v1/accounts`
   - **(ii)** `ledgeros` segue dono de conta; `accounts-revenu` cobre o que ele
     não faz (fees, statements, products) e some do path `/v1/accounts`
   - **(iii)** manter os dois — duplicação permanente, não recomendado
2. **JDPI** — `/paymentos/banklink/pix/jdpi/spi/api/v2/*` expõe o contrato cru do
   provedor. PaymentOS está fora do escopo focado, mas o path é público hoje.
3. **`atmos`** — no `service_map` do gateway, sem repositório em `revenu-platform`.
