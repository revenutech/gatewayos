# KrakenD Build on UBI

**Arquiteto Principal:** Gustavo Armoa

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

---

## Disclaimer — Recomendação Base

Este documento é uma **recomendação técnica de referência** elaborada como
baseline para o **Banco da Amazônia (BASA)** e **não constitui garantia
de segurança, conformidade regulatória ou funcionamento em produção**.

### Implementação por equipe especializada

A adoção e implementação efetiva deste plano **deve ser conduzida por
uma equipe DevSecOps especializada** nas seguintes tecnologias:

- **Oracle Cloud Infrastructure (OCI)** — arquitetura, IAM, networking,
  Vault, OCIR, observabilidade, compliance.
- **Red Hat OpenShift Container Platform (OCP)** — operação self-managed
  do cluster, SCC, Operators, Compliance Operator, atualizações.
- **Red Hat Enterprise Linux / UBI** — hardening, FIPS mode, supply
  chain de imagens, Red Hat Container Certification.

A ausência de profissionais com essa especialização inviabiliza a
execução segura deste plano.

### Governança de segurança — responsabilidade do Banco da Amazônia

A **governança de segurança da informação do Banco da Amazônia** deve
ser implementada, mantida e auditada com base na família de normas
**ISO/IEC 27000**:

- **ISO/IEC 27001:2022** — requisitos para sistemas de gestão de
  segurança da informação (ISMS).
- **ISO/IEC 27002:2022** — controles de segurança (Annex A, 93 controles).
- **ISO/IEC 27003** — diretrizes de implementação do ISMS.
- **ISO/IEC 27004** — monitoramento, medição, análise e avaliação de
  desempenho do ISMS.
- **ISO/IEC 27005** — gestão de riscos de segurança da informação.

Adicionalmente, **todas as boas práticas de segurança** aplicáveis ao
setor financeiro brasileiro devem ser incorporadas:

- NIST Cybersecurity Framework (CSF).
- CIS Benchmarks (Kubernetes, OpenShift, Red Hat Enterprise Linux).
- OWASP Top 10 / ASVS / SAMM.
- Resoluções **BACEN** (nº 4.893/2021 — Política de Segurança Cibernética,
  Resolução Conjunta 6/2023, entre outras aplicáveis a instituições
  financeiras).
- **Lei Geral de Proteção de Dados (LGPD — Lei 13.709/2018)**.
- SANS Critical Security Controls.

### Autoridade final

**O Banco da Amazônia é a autoridade final** sobre:

- A adequação deste plano ao contexto regulatório, operacional e de
  negócio da instituição.
- A aprovação técnica e executiva de qualquer controle, arquitetura ou
  decisão descrita neste documento.
- A implementação, operação, auditoria e evolução contínua do programa
  de segurança da informação.
- A responsabilidade legal, regulatória e contratual decorrente do uso
  deste material.

Este documento **não substitui** parecer jurídico, auditoria
independente, avaliação de risco formal, nem aprovação do Comitê de
Segurança da Informação do Banco da Amazônia.
