# Fase 01 — Docker UBI

Especificação da imagem de container do Gateway para o track Basa, usando
**Red Hat Universal Base Image 9 (UBI9-minimal)** como runtime em lugar do
Alpine 3.21 usado no track GCP. Mantém o mesmo binário KrakenD CE 2.9.4
patchado (CVE-2026-34986).

## Arquivos

| Documento | Finalidade |
|---|---|
| [dockerfile-strategy.md](dockerfile-strategy.md) | Multi-stage, stages, user non-root, entrypoint |
| [krakend-build-on-ubi.md](krakend-build-on-ubi.md) | Compilar KrakenD + patch go-jose em toolchain RH |
| [fips-readiness.md](fips-readiness.md) | Modo FIPS, Go FIPS, boringcrypto / OpenShift FIPS mode |
| [rh-container-certification.md](rh-container-certification.md) | Labels, licenses e checklist Red Hat Container Certification |

## Equivalência com track GCP

| Camada GCP | Camada Basa |
|---|---|
| `Dockerfile` (Alpine 3.21, user 1000, USAGE_DISABLE=1) | `docker/Dockerfile.ubi9` (UBI9-minimal, user 1001, idem) |
| `build/krakend/patch-deps.sh` | **Reutilizado sem alteração** — script é agnóstico de OS |
| `tools/compile-config.sh` | **Reutilizado sem alteração** — Python script |
| `wget` healthcheck | `curl` healthcheck (UBI já traz curl; wget requer extra package) |

## Checklist de fechamento da Fase 01

- [ ] `Dockerfile.ubi9` documentado e valida manualmente com `docker build`.
- [ ] Build do KrakenD patchado funciona com toolchain Go UBI (ou go-toolset).
- [ ] Imagem roda como UID aleatório (padrão OpenShift) sem quebrar.
- [ ] FIPS readiness avaliado — decisão documentada.
- [ ] Labels de RH Container Certification presentes.
- [ ] Trivy scan da imagem UBI não introduz CVEs novos relativos ao track GCP.

## Controles ISO 27001 tocados

- A.8.8 — Management of technical vulnerabilities (mesmo patch go-jose).
- A.8.9 — Configuration management (imagem reprodutível, tags imutáveis).
- A.8.19 — Installation of software on operational systems.
- A.8.24 — Use of cryptography (FIPS mode readiness).
- A.5.23 — Information security for use of cloud services (base image chain of trust).
