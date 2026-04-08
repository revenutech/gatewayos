# CD Production Pipeline

File: `.github/workflows/cd-production-gcp.yml`
Triggers: tags `v*.*.*` or `workflow_dispatch` (manual with image_tag input)

## Jobs

```
ci ──> build ──> deploy (requires approval) ──> post-deploy
```

### 1. ci

- KrakenD config validation
- Config audit (`--strict`)
- ISO compliance check (verify mandatory ISMS docs exist)

### 2. build

- Docker build with tag from git tag or workflow input
- **Trivy scan:** CRITICAL + HIGH, fail on findings
- **Cosign sign:** Container image signing
- **SBOM:** CycloneDX generation
- **SBOM attestation:** Cosign attest with CycloneDX predicate
- Push to production Artifact Registry

### 3. deploy

**Requires `production` environment approval** (GitHub environment protection rules).

- Helm upgrade with `--atomic` (auto-rollback on failure)
- Smoke tests:
  - `kubectl rollout status` (wait for rollout)
  - Pod status polling (20 attempts x 10s)
  - Port-forward health check (`curl /__health`)
- **Auto-rollback:** `helm rollback gateway 0` on any failure

### 4. post-deploy

- GitHub Release creation (for tag triggers)
- Slack notification

## Manual Deployment

```bash
# Via workflow_dispatch
gh workflow run cd-production-gcp.yml -f image_tag=v1.2.3
```

## Rollback

Automatic on deploy failure. Manual:
```bash
helm rollback gateway 0
kubectl rollout status deployment/gateway --timeout=120s
```

## Configuration

```yaml
env:
  GKE_CLUSTER: gateway-prod-cluster
  GKE_REGION: southamerica-east1
  AR_REPO: southamerica-east1-docker.pkg.dev/revenu-gateway-production/gateway-prod
```
