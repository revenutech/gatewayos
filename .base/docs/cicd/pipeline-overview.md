# Pipeline Overview

5 GitHub Actions pipelines at `.github/workflows/`.

## Pipeline Map

```
PR to main ──────┬──> ci.yml (validate, audit, build, scan)
                 └──> compliance.yml (ISO 27001 checks)
                          |
push to develop ─────────> cd-dev-gcp.yml ──> GKE Dev
                          |
push to staging ─────────> cd-staging-gcp.yml ──> GKE Staging
                          |
tag v*.*.* ──────────────> cd-production-gcp.yml ──> GKE Production
                                    (requires approval)
```

## Promotion Flow

1. **PR** → CI + Compliance validation
2. **Merge to develop** → Auto-deploy to GKE Dev
3. **Merge to staging** → Auto-deploy to GKE Staging (+ Cosign signing)
4. **Tag v*.*.*** → Deploy to GKE Production (manual approval + SBOM + Trivy + Cosign)

## GCP Infrastructure

| Setting | Value |
|---------|-------|
| Region | southamerica-east1 |
| Auth | Workload Identity Federation (no service account keys) |
| Registry | Artifact Registry (southamerica-east1-docker.pkg.dev) |
| Orchestration | Helm |

## Image Naming

| Environment | Tag Pattern | Registry |
|-------------|------------|----------|
| Dev | `dev-{commit_sha}` + `dev-latest` | revenu-gateway-dev/gateway-dev/gateway |
| Staging | `staging-{commit_sha}` | revenu-gateway-staging/gateway-staging/gateway |
| Production | `v*.*.*` (semver) | revenu-gateway-production/gateway-prod/gateway |

## Supply Chain Security

| Feature | Dev | Staging | Production |
|---------|-----|---------|------------|
| Config validation | Yes | Yes | Yes |
| Trivy scan | Yes (CI) | Yes | Yes |
| SBOM generation | Yes (CI) | Yes | Yes |
| Cosign signing | — | Yes | Yes |
| SBOM attestation | — | — | Yes |
| Manual approval | — | — | Yes |
