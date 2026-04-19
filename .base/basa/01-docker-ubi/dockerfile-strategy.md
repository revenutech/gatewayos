# Dockerfile Strategy — UBI9

## Objetivo

Produzir `docker/Dockerfile.ubi9` baseado em **Red Hat UBI9-minimal** no
runtime, com o binário KrakenD CE 2.9.4 patchado e a compilação do FC
Template.

## Imagens por stage

| Stage | Imagem |
|---|---|
| 1. Build KrakenD | `registry.access.redhat.com/ubi9/go-toolset:1.24` |
| 2. Compile FC | `registry.access.redhat.com/ubi9/python-312` |
| 3. Runtime | `registry.access.redhat.com/ubi9/ubi-minimal:9.4` |

## Desenho (3 stages)

### Stage 1 — `krakend-builder`

- Base: `ubi9/go-toolset:1.24` (Red Hat build of Go, já FIPS-aware).
- Instala `git` e `make` via `microdnf` (toolset já tem gcc).
- Executa `build/krakend/patch-deps.sh` (script de patch go-jose).
- Sai com binário `/build/krakend`.

### Stage 2 — `compiler`

- Base: `ubi9/python-312`.
- Copia `krakend/` e `tools/compile-config.sh`.
- Vars: `KRAKEND_DIR=/etc/krakend`, `ENV=sqa|uat|pro` (build arg), `OUTPUT=/etc/krakend/krakend.json`.
- Executa `sh /compile-config.sh` → gera JSON estático.

### Stage 3 — `runtime`

- Base: `ubi9/ubi-minimal:9.4`.
- `microdnf install -y ca-certificates curl shadow-utils tzdata` + `microdnf clean all`.
- Cria usuário `krakend` com UID fixo 1001 e grupo root (0) — **compatível com OpenShift random UID**.
  ```
  useradd -u 1001 -g 0 -s /sbin/nologin -m -d /home/krakend krakend
  chgrp -R 0 /etc/krakend /home/krakend && chmod -R g=u /etc/krakend /home/krakend
  ```
- Copia binário do stage 1 e JSON compilado do stage 2.
- Copia `krakend/partials/lua/` (scripts Lua usados em runtime).
- ENV:
  ```
  FC_ENABLE=0
  KRAKEND_PORT=8080
  USAGE_DISABLE=1
  ```
- `EXPOSE 8080 8090`.
- `USER 1001`.
- `HEALTHCHECK` via `curl -fsS http://localhost:8080/__health` (curl já disponível no UBI).
- `ENTRYPOINT ["krakend"]`, `CMD ["run", "-c", "/etc/krakend/krakend.json"]`.

## OpenShift — random UID

OpenShift atribui um **UID aleatório** em cada pod (ex: `1000650000`), não
respeita `USER 1001` do Dockerfile por padrão (SCC `restricted-v2`).

Para funcionar:

1. **Não depender do UID específico** — binário + config precisam ser
   legíveis por `GID 0` (root group).
2. `chgrp -R 0 /etc/krakend && chmod -R g=rwX /etc/krakend`.
3. **Ponto de home writable** — `/home/krakend` com GID 0 e permissão `g=rwX`.
4. Se for preciso forçar UID 1001 (ex: FIPS boundary), usar SCC
   `anyuid` via RoleBinding explícito (registrado em Fase 03 + ADR se
   necessário).

## Labels obrigatórios (entram em detalhe em rh-container-certification.md)

```
LABEL name="revenu-platform/gateway"
LABEL vendor="Revenu"
LABEL version="2.9.4-basa"
LABEL release="1"
LABEL summary="Revenu Platform API Gateway (KrakenD CE 2.9.4 patched, UBI9)"
LABEL description="API Gateway for the Revenu Platform — UBI9 build track (Basa)"
LABEL maintainer="platform@revenu.com.br"
LABEL io.k8s.display-name="Revenu Gateway (UBI)"
LABEL io.openshift.tags="api-gateway,krakend,revenu"
LABEL url="https://github.com/revenutech/revenu-platform"
LABEL license="Apache-2.0"
```

Arquivo `licenses/` copiado para `/licenses/` na imagem (exigência Red Hat cert).

## Build args

| Arg | Default | Uso |
|---|---|---|
| `ENV` | `sqa` | passa para compile-config.sh |
| `KRAKEND_VERSION` | `2.9.4` | marca LDFLAGS e LABEL version |
| `BUILD_SHA` | (vazio) | grava em LABEL para rastreabilidade |

## Características da imagem

| Item | Valor | Motivo |
|---|---|---|
| Base runtime | ubi9/ubi-minimal:9.4 | Stack RH, FIPS-ready |
| Healthcheck | `curl -fsS` | UBI traz curl por padrão |
| UID | 1001 + GID 0 | Compat OpenShift random UID |
| Package mgr | `microdnf` | Padrão do UBI-minimal |
| Image size | ~80 MB | Inclui certificação RH |

## Checklist pronto-para-código

- [ ] `docker/Dockerfile.ubi9` criado conforme stages acima.
- [ ] `.dockerignore` atualizado se necessário.
- [ ] `docker build -f docker/Dockerfile.ubi9 .` roda localmente.
- [ ] `docker run` com `--user=$((RANDOM+1000000))` funciona (valida OpenShift-compat).
- [ ] Healthcheck retorna `200` em `/__health`.
- [ ] Imagem aprovada por `trivy image --severity CRITICAL,HIGH` sem achados não-tratados.
- [ ] Docs de build referenciados em `01-docker-ubi/krakend-build-on-ubi.md`.
