# CD UAT — `cd-uat-oci.yml`

## Objetivo

Deploy automático no OpenShift uat a cada push em `staging`, com
todos os gates de sqa **mais**:

- Cosign keyless signing (Fase 05).
- SBOM CycloneDX + `cosign attest`.
- Smoke test HTTP mais extenso (10 requests, valida p99).
- Retenção de image tag `uat-rc-{n}`.

## Trigger

```yaml
on:
  push:
    branches: [staging]
    paths: (mesma lista de cd-sqa-oci)
  workflow_dispatch:
```

## Environment

`uat-oci` — 1 reviewer recomendado (não obrigatório v1).

## Jobs — estrutura

```
ci-revalidate  (config audit + ISO checks)
    ▼
build-sign-scan   (build + Trivy + push + Cosign sign + SBOM attest)
    ▼
deploy           (helm upgrade atomic + smoke)
    ▼
post-deploy      (Slack + tag imagem uat-rc-{n})
```

## YAML esqueleto

```yaml
name: CD — UAT (OCI/OpenShift)

on:
  push:
    branches: [staging]
  workflow_dispatch:

concurrency:
  group: cd-uat-oci
  cancel-in-progress: false        # uat não cancela — deploy termina

env:
  OCP_NAMESPACE: gateway-uat
  HELM_RELEASE: gateway
  IMAGE_NAME: gateway

jobs:
  ci-revalidate:
    name: Re-validate config + ISO
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: KrakenD config audit (strict)
        run: bash tools/config-audit/audit.sh --strict
      - name: Validate compile
        run: |
          bash tools/compile-config.sh krakend uat /tmp/out.json
          python3 -c "import json; json.load(open('/tmp/out.json'))"
      - name: ISO docs check
        run: |
          for doc in .base/docs/isms/scope-statement.md .base/docs/risk/risk-register.md .base/docs/compliance/controls-matrix.md; do
            [ -f "$doc" ] || { echo "MISSING: $doc"; exit 1; }
          done

  build-sign-scan:
    name: Build, Sign, SBOM attest, Push
    needs: ci-revalidate
    runs-on: ubuntu-latest
    environment: uat-oci
    permissions:
      contents: read
      id-token: write
      packages: write
    outputs:
      image_digest: ${{ steps.push.outputs.digest }}
      image_tag: ${{ steps.tag.outputs.tag }}
    steps:
      - uses: actions/checkout@v4

      - id: tag
        run: echo "tag=uat-${{ github.sha }}" >> $GITHUB_OUTPUT

      - name: Configure OCI CLI
        uses: oracle-actions/configure-oci-cli@v1.3.2
        with:
          tenancy-ocid: ${{ secrets.OCI_TENANCY_OCID }}
          token-exchange-url: https://auth.${{ secrets.OCI_REGION_UAT }}.oraclecloud.com/v1/oauth2/token

      - name: OCIR login
        run: |
          oci raw-request --http-method POST \
            --target-uri "https://identity.${{ secrets.OCI_REGION_UAT }}.oraclecloud.com/20160918/auth-tokens" \
            --request-body '{"description":"gh-actions-uat-${{ github.run_id }}"}' \
            | jq -r '.data.token' | docker login gru.ocir.io \
              -u "${{ secrets.OCI_TENANCY_NAMESPACE }}/oke-ci" --password-stdin

      - name: Build UBI9 image
        run: |
          docker build \
            -f docker/Dockerfile.ubi9 \
            --build-arg ENV=uat \
            --build-arg KRAKEND_VERSION=2.9.4 \
            --build-arg BUILD_SHA=${{ github.sha }} \
            -t "${{ secrets.OCIR_REPO_UAT }}/${{ env.IMAGE_NAME }}:${{ steps.tag.outputs.tag }}" \
            .

      - name: Trivy scan (block on CRITICAL/HIGH fixable)
        uses: aquasecurity/trivy-action@master
        with:
          image-ref: ${{ secrets.OCIR_REPO_UAT }}/${{ env.IMAGE_NAME }}:${{ steps.tag.outputs.tag }}
          format: sarif
          output: trivy.sarif
          exit-code: 1
          severity: CRITICAL,HIGH
          ignore-unfixed: true

      - uses: github/codeql-action/upload-sarif@v3
        if: always()
        with:
          sarif_file: trivy.sarif

      - id: push
        name: Push image
        run: |
          docker push "${{ secrets.OCIR_REPO_UAT }}/${{ env.IMAGE_NAME }}:${{ steps.tag.outputs.tag }}"
          DIGEST=$(docker inspect "${{ secrets.OCIR_REPO_UAT }}/${{ env.IMAGE_NAME }}:${{ steps.tag.outputs.tag }}" --format='{{index .RepoDigests 0}}' | cut -d@ -f2)
          echo "digest=$DIGEST" >> $GITHUB_OUTPUT

      # --- Cosign sign ---
      - uses: sigstore/cosign-installer@v3
        with:
          cosign-release: v2.4.0

      - name: Cosign sign (by digest)
        env:
          COSIGN_EXPERIMENTAL: "1"
        run: |
          cosign sign --yes \
            "${{ secrets.OCIR_REPO_UAT }}/${{ env.IMAGE_NAME }}@${{ steps.push.outputs.digest }}"

      # --- SBOM ---
      - name: Generate SBOM
        uses: aquasecurity/trivy-action@master
        with:
          image-ref: ${{ secrets.OCIR_REPO_UAT }}/${{ env.IMAGE_NAME }}:${{ steps.tag.outputs.tag }}
          format: cyclonedx
          output: sbom.cdx.json

      - name: Attest SBOM
        env:
          COSIGN_EXPERIMENTAL: "1"
        run: |
          cosign attest --yes \
            --predicate sbom.cdx.json \
            --type cyclonedx \
            "${{ secrets.OCIR_REPO_UAT }}/${{ env.IMAGE_NAME }}@${{ steps.push.outputs.digest }}"

      - uses: actions/upload-artifact@v4
        with:
          name: sbom-uat
          path: sbom.cdx.json

      # --- SLSA provenance ---
      - uses: actions/attest-build-provenance@v1
        with:
          subject-name: ${{ secrets.OCIR_REPO_UAT }}/${{ env.IMAGE_NAME }}
          subject-digest: ${{ steps.push.outputs.digest }}
          push-to-registry: true

  deploy:
    name: Deploy to OpenShift UAT
    needs: build-sign-scan
    runs-on: ubuntu-latest
    environment: uat-oci
    permissions:
      contents: read
      id-token: write
    steps:
      - uses: actions/checkout@v4
      - uses: oracle-actions/configure-oci-cli@v1.3.2
        with:
          tenancy-ocid: ${{ secrets.OCI_TENANCY_OCID }}
          token-exchange-url: https://auth.${{ secrets.OCI_REGION_UAT }}.oraclecloud.com/v1/oauth2/token

      - name: Fetch kubeconfig
        run: |
          mkdir -p ~/.kube
          oci secrets secret-bundle get \
            --secret-id ${{ secrets.OCP_KUBECONFIG_SECRET_OCID_UAT }} \
            --query 'data."secret-bundle-content".content' --raw-output \
            | base64 -d > ~/.kube/config
          chmod 600 ~/.kube/config

      # --- Verify signature before deploy ---
      - uses: sigstore/cosign-installer@v3

      - name: Verify signature + SBOM
        run: |
          cosign verify \
            --certificate-identity-regexp "^https://github.com/revenutech/revenu-platform-gateway/\\.github/workflows/cd-uat-oci\\.yml@refs/heads/staging$" \
            --certificate-oidc-issuer "https://token.actions.githubusercontent.com" \
            "${{ secrets.OCIR_REPO_UAT }}/${{ env.IMAGE_NAME }}@${{ needs.build-sign-scan.outputs.image_digest }}"
          cosign verify-attestation \
            --type cyclonedx \
            --certificate-identity-regexp "^https://github.com/revenutech/revenu-platform-gateway/\\.github/workflows/cd-uat-oci\\.yml@refs/heads/staging$" \
            --certificate-oidc-issuer "https://token.actions.githubusercontent.com" \
            "${{ secrets.OCIR_REPO_UAT }}/${{ env.IMAGE_NAME }}@${{ needs.build-sign-scan.outputs.image_digest }}"

      - uses: azure/setup-helm@v4
      - name: Helm upgrade (atomic)
        run: |
          helm upgrade --install "${{ env.HELM_RELEASE }}" k8s/helm/gateway \
            -n "${{ env.OCP_NAMESPACE }}" --create-namespace \
            -f k8s/helm/gateway/values-oci-uat.yaml \
            --set image.repository="${{ secrets.OCIR_REPO_UAT }}/${{ env.IMAGE_NAME }}" \
            --set image.tag="${{ needs.build-sign-scan.outputs.image_tag }}" \
            --set configHash=${{ github.sha }} \
            --atomic --wait --timeout 8m

      - name: Extensive smoke test
        run: |
          HOST=$(kubectl -n "${{ env.OCP_NAMESPACE }}" get route gateway -o jsonpath='{.spec.host}')
          for i in $(seq 1 10); do
            curl -fsS --max-time 10 "https://${HOST}/__health" >/dev/null || { echo "smoke $i failed"; exit 1; }
          done
          # latency sanity
          TIME=$(curl -o /dev/null -s -w "%{time_total}\n" "https://${HOST}/__health")
          echo "latency=${TIME}s"

      - name: Rollback on failure
        if: failure()
        run: |
          helm rollback "${{ env.HELM_RELEASE }}" -n "${{ env.OCP_NAMESPACE }}" 0
          kubectl -n "${{ env.OCP_NAMESPACE }}" rollout status deploy/gateway --timeout=3m

  post-deploy:
    needs: [build-sign-scan, deploy]
    if: success()
    runs-on: ubuntu-latest
    steps:
      - name: Notify Slack
        uses: slackapi/slack-github-action@v1
        with:
          payload: |
            {"text":"✅ Gateway uat-oci deploy OK — `${{ needs.build-sign-scan.outputs.image_tag }}`"}
        env:
          SLACK_WEBHOOK_URL: ${{ secrets.SLACK_WEBHOOK_URL }}
```

## Diferenças vs sqa

| Item | sqa | uat |
|---|---|---|
| Config audit | opcional | obrigatório |
| ISO docs check | opcional | obrigatório |
| Trivy | block CRITICAL/HIGH | idem |
| SARIF upload | não | sim |
| Cosign sign | não | **sim** |
| SBOM + attest | não | **sim** |
| SLSA provenance | não | **sim** |
| Helm `--atomic` | não | **sim** |
| Verify sig antes deploy | não | **sim** |
| Smoke test | 1 request | 10 requests + latency |
| Rollback auto | não | **sim** |

## Decisões de design

1. **Sign/attest só daqui para cima** — sqa é barato e descartável.
2. **`--atomic`** em Helm — rollback transparente em falha.
3. **Verify signature antes deploy** — mesmo sendo o mesmo workflow que
   assinou, garante que ninguém mexeu entre push e deploy.
4. **Rollback auto em falha** — uat precisa ficar estável entre releases.
5. **Smoke extensivo** — 10 requests detectam quebras intermitentes.

## Controles ISO 27001

- A.8.9 — Configuration management.
- A.8.24 — Cryptography (sign).
- A.8.25 — Secure development.
- A.8.32 — Change management.

## Checklist pronto-para-código

- [ ] Workflow `cd-uat-oci.yml` criado.
- [ ] Cosign signing funciona (verify passa).
- [ ] SBOM attestation recuperável via `cosign verify-attestation`.
- [ ] Rollback automático testado (deploy broken → reverteu).
- [ ] SLSA provenance visível no GitHub Attestations.
