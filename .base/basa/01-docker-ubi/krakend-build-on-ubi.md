# KrakenD Build on UBI

## Objetivo

Compilar o binário **KrakenD CE 2.9.4 + patch go-jose** num toolchain
suportado pela Red Hat, produzindo um artefato compatível com UBI9-minimal
em runtime e elegível para FIPS mode.

## Parâmetros de build

| Item | Valor |
|---|---|
| Base build | `ubi9/go-toolset:1.24` |
| Script patch | `build/krakend/patch-deps.sh` |
| Binário final | glibc dynamic-link |
| LDFLAGS | versão + tag `patched` |

## Por que `go-toolset` da Red Hat

- **Suportado pela Red Hat** — entra na cadeia de suporte OCP + subscription.
- **FIPS-ready** — build with `GOEXPERIMENT=boringcrypto` é opcional mas
  simples de habilitar.
- **Patches de CVE aplicados regularmente** — vs Alpine que depende da
  comunidade.
- **UBI-based** — roda sem ajustes no pipeline de CI.

## Fluxo de build

1. **Clona** KrakenD CE 2.9.4 (mesmo passo do script atual).
2. **Aplica replace de go-jose** v3.0.5 e v4.1.4 (CVE-2026-34986).
3. **`go mod tidy`**.
4. **Compila**:
   - Padrão (não-FIPS): `go build -ldflags=... -o /build/krakend ./cmd/krakend-ce`.
   - FIPS (opcional): `GOEXPERIMENT=boringcrypto CGO_ENABLED=1 go build ...`
     (vira discussão em `fips-readiness.md`).
5. **Smoke test**: `/build/krakend version` deve imprimir `2.9.4-patched`.

## Dependências de build (instaladas no go-toolset)

`microdnf install -y make git gcc` (toolset já traz Go, libc-devel, kernel-headers).

## Checksum e reprodutibilidade

- Fixar `GOFLAGS=-trimpath` para path-agnostic builds.
- Fixar `SOURCE_DATE_EPOCH` ao SHA do commit para mtime determinístico.
- Pin de versões:
  - Go: `1.24.x` (toolset auto-patcheia minor).
  - KrakenD: tag `v2.9.4` (imutável).
  - go-jose: `v3.0.5` / `v4.1.4` (imutáveis).
- Hash SHA256 do binário deve ser registrado em CI para attestation
  (entra em Fase 05 — SBOM + provenance).

## Static vs dynamic link

O binário da Alpine é **estático com musl**; no UBI fica **dinâmico com glibc**.
Impacto:

- Rodar em UBI-minimal: ✅ OK (glibc disponível).
- Rodar em `scratch` ou `distroless`: ❌ quebra — exige static build.
- **Decisão:** manter dinâmico; UBI é o runtime-alvo.

Alternativa futura se quisermos scratch: `CGO_ENABLED=0 go build -tags netgo`
para estático puro — perde FIPS via boringcrypto.

## Verificação após build

```
krakend version          # deve imprimir 2.9.4-patched
krakend check -d         # ajuda — valida toolchain
krakend check -c /etc/krakend/krakend.json  # valida config
```

## Integração no Dockerfile.ubi9

O stage `krakend-builder` executa:

```
FROM registry.access.redhat.com/ubi9/go-toolset:1.24 AS krakend-builder
USER 0
RUN microdnf install -y git make gcc && microdnf clean all
WORKDIR /build
COPY build/krakend/patch-deps.sh /build/patch-deps.sh
RUN chmod +x /build/patch-deps.sh && /build/patch-deps.sh
```

`patch-deps.sh` não precisa mudar — ele funciona em qualquer distro com
Go + git.

## Riscos e mitigações

| Risco | Mitigação |
|---|---|
| `go-toolset` atualiza Go minor e quebra build | Pin explícito com `go mod go=1.24.X` + lockfile de go.sum |
| Patch go-jose se torna upstream | Remover replace quando KrakenD CE publicar versão nova ≥ 2.9.5 |
| FIPS exige GOEXPERIMENT, incompatível com alguns hashers | Ver `fips-readiness.md` antes de habilitar |

## Checklist pronto-para-código

- [ ] Stage `krakend-builder` no `Dockerfile.ubi9` usando `ubi9/go-toolset:1.24`.
- [ ] `patch-deps.sh` copiado sem modificação (reutilizado).
- [ ] Build local com `docker build --target krakend-builder` produz binário válido.
- [ ] `krakend version` imprime `2.9.4-patched`.
- [ ] SHA256 do binário capturado em CI para provenance (Fase 05).
