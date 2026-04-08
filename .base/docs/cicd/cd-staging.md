# CD Staging Pipeline

File: `.github/workflows/cd-staging-gcp.yml`
Triggers: push to `staging` branch

## Steps

1. **CI Validation:** Config check + audit
2. **Build:** Docker image tagged `staging-{sha}`
3. **Cosign Sign:** Container image signing via Sigstore
4. **Push:** To staging Artifact Registry
5. **Deploy:** Helm upgrade with `values-gcp-staging.yaml`, `--atomic --wait 5m`
6. **Health check:** Pod status verification
7. **Notify:** Slack notification on success/failure

## Key Differences from Dev

| Feature | Dev | Staging |
|---------|-----|---------|
| Cosign signing | No | Yes |
| Helm deploy mode | --wait | --atomic (auto-rollback) |
| CI validation | No (separate CI pipeline) | Included in CD |
