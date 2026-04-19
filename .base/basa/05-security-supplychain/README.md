# Fase 05 — Security & Supply Chain

Especificação dos controles de segurança e supply chain do track Basa:
assinatura Cosign keyless, SBOM CycloneDX, scanning Trivy, admission
policies, FIPS mode (referência cruzada com Fase 01) e fluxo de secrets
via OCI Vault + External Secrets Operator.

## Arquivos

| Documento | Foco |
|---|---|
| [cosign-keyless-oidc.md](cosign-keyless-oidc.md) | Assinatura sem keys via GitHub OIDC + Fulcio/Rekor + policy-controller |
| [sbom-cyclonedx.md](sbom-cyclonedx.md) | Geração, assinatura e attestation do SBOM |
| [trivy-scanning.md](trivy-scanning.md) | Scan de imagem, config, filesystem, .trivyignore herdado |
| [red-hat-acs-stackrox.md](red-hat-acs-stackrox.md) | Plano opcional v2 (decisão consolidada em ADR-004) |
| [fips-mode.md](fips-mode.md) | Cross-reference com Fase 01, checklist de ativação |
| [secrets-flow.md](secrets-flow.md) | OCI Vault → External Secrets Operator → Kubernetes Secret |

## Princípios

1. **Baseline mínima mandatória** — todo release pro passa por Cosign sign,
   Trivy scan CRITICAL/HIGH bloqueante e SBOM CycloneDX attest.
2. **Zero key estática** — tudo via OIDC / Resource Principal / ESO.
3. **Assinatura e attestation como gate de CD** — pro não aceita imagem
   sem Cosign sig + SBOM attest.
4. **SBOM versionado** — publicado como release artifact.
5. **FIPS-ready**, **não FIPS-on** v1 (Fase 01 + ADR-004).

## Camadas de defesa

```
┌─────────────────────────────────────────────┐
│ Build-time (Fase 06 — CI workflows)         │
├─────────────────────────────────────────────┤
│ 1. Trivy fs scan (código)                   │
│ 2. Dockerfile build (UBI9)                  │
│ 3. Trivy image scan (CRITICAL/HIGH block)   │
│ 4. Cosign sign (keyless GH OIDC)            │
│ 5. SBOM CycloneDX + cosign attest           │
│ 6. Push OCIR                                │
└─────────────────────────────────────────────┘
                   ▼
┌─────────────────────────────────────────────┐
│ Admission-time (opcional v1, recomend. v2)  │
├─────────────────────────────────────────────┤
│ Sigstore policy-controller:                 │
│  - Exige cosign signature para pull         │
│  - Exige SBOM attestation                   │
└─────────────────────────────────────────────┘
                   ▼
┌─────────────────────────────────────────────┐
│ Runtime (OpenShift)                         │
├─────────────────────────────────────────────┤
│ 1. SCC restricted-v2 (Fase 03)              │
│ 2. NetworkPolicy OVN-K (Fase 03)            │
│ 3. PSA restricted (Fase 03)                 │
│ 4. Compliance Operator (Fase 03)            │
│ 5. Secrets via ESO + OCI Vault              │
└─────────────────────────────────────────────┘
```

## Checklist de fechamento da Fase 05

- [ ] Cosign keyless documentado e testado localmente.
- [ ] SBOM pipeline anexa ao release.
- [ ] Trivy scan bloqueia CI quando CVEs CRITICAL/HIGH.
- [ ] ACS decision documentada (plano v2 explícito).
- [ ] FIPS readiness referenciado (Fase 01 + checklist de ativação).
- [ ] Secrets flow — ESO sincroniza Vault → Secret K8s em test cluster.
- [ ] Admission policy (Sigstore) documentada, **opcional** na v1.

## Controles ISO 27001 tocados

- A.5.17 — Authentication information (secrets não em código).
- A.5.23 — Information security for use of cloud services.
- A.8.4 — Access to source code (repositório + assinatura).
- A.8.5 — Secure authentication (MFA GitHub, OIDC).
- A.8.8 — Management of technical vulnerabilities.
- A.8.9 — Configuration management (supply chain íntegro).
- A.8.12 — Data leakage prevention.
- A.8.24 — Use of cryptography (Cosign + FIPS-ready).
- A.8.25 — Secure development life cycle.
- A.8.28 — Secure coding.
- A.8.30 — Outsourced development (base image Red Hat + KrakenD CE).
