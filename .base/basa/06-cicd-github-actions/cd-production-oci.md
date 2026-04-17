# CD Production — `cd-production-oci.yml`

## Objetivo

Deploy em produção apenas via tag `v*.*.*` ou `workflow_dispatch`, com
todos os gates de staging **mais**:

- **Approval manual** obrigatório (GitHub Environment protection).
- **Prod-specific Trivy policy** (inclui MEDIUM).
- **Smoke test pós-deploy** extenso (30s).
- **Rollback automático** em falha.
- **GitHub Release** com SBOM como artifact.
- **Slack + ticket** em pós-deploy.

Paridade com `cd-production-gcp.yml`.

## Trigger

```yaml
on:
  workflow_dispatch:
    inputs:
      image_tag:
        description: "Image tag (ex: v1.2.3)"
        required: true
      change_ticket:
        description: "ID do ticket / PR de mudança"
        required: true
  push:
    tags: ['v*.*.*']
```

## Environment

`production-oci`:
- **2 reviewers** obrigatórios.
- Branches permitidos: tags `v*.*.*` **apenas**.
- Wait timer 5 min (opcional — dá chance de cancelar).

## Concurrency

```yaml
concurrency:
  group: cd-production-oci
  cancel-in-progress: false       # nunca cancela prod mid-flight
```

## Jobs — estrutura

```
ci-revalidate
    ▼
build-sign-scan   (idem staging + scan MEDIUM)
    ▼
deploy            (approval → helm atomic → smoke extensivo → rollback auto)
    ▼
post-deploy       (Release + Slack + update OCI Vault tag)
```

## YAML esqueleto (diffs vs staging)

```yaml
name: CD — Production (OCI/OpenShift)

on:
  workflow_dispatch:
    inputs:
      image_tag:
        required: true
      change_ticket:
        required: true
  push:
    tags: ['v*.*.*']

concurrency:
  group: cd-production-oci
  cancel-in-progress: false

env:
  OCP_NAMESPACE: gateway-prod
  HELM_RELEASE: gateway
  IMAGE_NAME: gateway

jobs:
  ci-revalidate:
    (igual staging, mas com audit.sh --strict --env=prod)

  build-sign-scan:
    runs-on: ubuntu-latest
    needs: ci-revalidate
    environment: production-oci     # approval AQUI (antes de build)
    permissions:
      contents: read
      id-token: write
    outputs:
      image_digest: ${{ steps.push.outputs.digest }}
      image_tag: ${{ steps.tag.outputs.tag }}
    steps:
      - uses: actions/checkout@v4

      - id: tag
        run: |
          if [ "${{ github.event_name }}" = "workflow_dispatch" ]; then
            echo "tag=${{ github.event.inputs.image_tag }}" >> $GITHUB_OUTPUT
          else
            echo "tag=${GITHUB_REF_NAME}" >> $GITHUB_OUTPUT
          fi

      # ... OCI CLI + OCIR login (mesmo que staging, com _PROD secrets)

      - name: Build
        run: |
          docker build -f docker/Dockerfile.ubi9 \
            --build-arg ENV=prod \
            --build-arg KRAKEND_VERSION=2.9.4 \
            --build-arg BUILD_SHA=${{ github.sha }} \
            -t "${{ secrets.OCIR_REPO_PROD }}/${{ env.IMAGE_NAME }}:${{ steps.tag.outputs.tag }}" .

      # Trivy PROD policy — inclui MEDIUM
      - name: Trivy image (strict)
        uses: aquasecurity/trivy-action@master
        with:
          image-ref: ${{ secrets.OCIR_REPO_PROD }}/${{ env.IMAGE_NAME }}:${{ steps.tag.outputs.tag }}
          format: sarif
          output: trivy.sarif
          exit-code: 1
          severity: CRITICAL,HIGH,MEDIUM
          ignore-unfixed: true

      # Push / Sign / SBOM / Attest / SLSA — idem staging
      - id: push
        (idem)

      - uses: sigstore/cosign-installer@v3

      - name: Cosign sign
        run: cosign sign --yes "${{ secrets.OCIR_REPO_PROD }}/${{ env.IMAGE_NAME }}@${{ steps.push.outputs.digest }}"

      - name: Generate SBOM
        uses: aquasecurity/trivy-action@master
        with:
          image-ref: ${{ secrets.OCIR_REPO_PROD }}/${{ env.IMAGE_NAME }}:${{ steps.tag.outputs.tag }}
          format: cyclonedx
          output: sbom.cdx.json

      - name: Attest SBOM
        run: |
          cosign attest --yes --predicate sbom.cdx.json --type cyclonedx \
            "${{ secrets.OCIR_REPO_PROD }}/${{ env.IMAGE_NAME }}@${{ steps.push.outputs.digest }}"

      - uses: actions/attest-build-provenance@v1
        with:
          subject-name: ${{ secrets.OCIR_REPO_PROD }}/${{ env.IMAGE_NAME }}
          subject-digest: ${{ steps.push.outputs.digest }}
          push-to-registry: true

      - uses: actions/upload-artifact@v4
        with:
          name: sbom-prod-${{ steps.tag.outputs.tag }}
          path: sbom.cdx.json

  deploy:
    needs: build-sign-scan
    runs-on: ubuntu-latest
    environment: production-oci     # approval de novo? Não — mesmo environment, já aprovado no build
    permissions:
      contents: read
      id-token: write
    steps:
      - uses: actions/checkout@v4
      (OCI CLI + kubeconfig do Vault igual staging, com _PROD secrets)

      - uses: sigstore/cosign-installer@v3

      - name: Verify sig + SBOM
        run: |
          SUBJECT="^https://github.com/revenutech/revenu-platform-gateway/\\.github/workflows/cd-production-oci\\.yml@refs/tags/v"
          cosign verify \
            --certificate-identity-regexp "$SUBJECT" \
            --certificate-oidc-issuer "https://token.actions.githubusercontent.com" \
            "${{ secrets.OCIR_REPO_PROD }}/${{ env.IMAGE_NAME }}@${{ needs.build-sign-scan.outputs.image_digest }}"
          cosign verify-attestation --type cyclonedx \
            --certificate-identity-regexp "$SUBJECT" \
            --certificate-oidc-issuer "https://token.actions.githubusercontent.com" \
            "${{ secrets.OCIR_REPO_PROD }}/${{ env.IMAGE_NAME }}@${{ needs.build-sign-scan.outputs.image_digest }}"

      - uses: azure/setup-helm@v4

      - name: Helm upgrade atomic
        run: |
          helm upgrade --install "${{ env.HELM_RELEASE }}" k8s/helm/gateway \
            -n "${{ env.OCP_NAMESPACE }}" --create-namespace \
            -f k8s/helm/gateway/values-oci-production.yaml \
            --set image.repository="${{ secrets.OCIR_REPO_PROD }}/${{ env.IMAGE_NAME }}" \
            --set image.tag="${{ needs.build-sign-scan.outputs.image_tag }}" \
            --set configHash=${{ github.sha }} \
            --set "annotations.platform\.revenu/change-ticket=${{ github.event.inputs.change_ticket || github.ref_name }}" \
            --atomic --wait --timeout 10m

      - name: Extensive smoke (30s)
        run: |
          HOST=$(kubectl -n "${{ env.OCP_NAMESPACE }}" get route gateway -o jsonpath='{.spec.host}')
          END=$(( $(date +%s) + 30 ))
          COUNT=0; FAILS=0
          while [ $(date +%s) -lt $END ]; do
            COUNT=$((COUNT+1))
            curl -fsS --max-time 5 "https://${HOST}/__health" >/dev/null || FAILS=$((FAILS+1))
            sleep 1
          done
          echo "smoke=${COUNT} fails=${FAILS}"
          [ $FAILS -le 2 ] || exit 1       # tolera ≤2 falhas em 30 tentativas

      - name: Rollback on failure
        if: failure()
        run: |
          helm rollback "${{ env.HELM_RELEASE }}" -n "${{ env.OCP_NAMESPACE }}" 0
          kubectl -n "${{ env.OCP_NAMESPACE }}" rollout status deploy/gateway --timeout=5m

  post-deploy:
    needs: [build-sign-scan, deploy]
    if: success()
    runs-on: ubuntu-latest
    permissions:
      contents: write
    steps:
      - uses: actions/checkout@v4
      - uses: actions/download-artifact@v4
        with:
          name: sbom-prod-${{ needs.build-sign-scan.outputs.image_tag }}

      - name: GitHub Release
        uses: softprops/action-gh-release@v1
        if: startsWith(github.ref, 'refs/tags/')
        with:
          generate_release_notes: true
          files: |
            sbom.cdx.json

      - name: Notify Slack
        uses: slackapi/slack-github-action@v1
        with:
          payload: |
            {"text":"🚀 Gateway PROD-OCI deploy OK — `${{ needs.build-sign-scan.outputs.image_tag }}` — ticket: `${{ github.event.inputs.change_ticket || github.ref_name }}`"}
        env:
          SLACK_WEBHOOK_URL: ${{ secrets.SLACK_WEBHOOK_URL }}

      - name: Notify Slack (failure)
        if: failure()
        uses: slackapi/slack-github-action@v1
        with:
          payload: |
            {"text":"🚨 Gateway PROD-OCI deploy FAILED — `${{ needs.build-sign-scan.outputs.image_tag }}` — ROLLBACK DISPARADO"}
        env:
          SLACK_WEBHOOK_URL: ${{ secrets.SLACK_WEBHOOK_URL }}
```

## Diferenças vs staging

| Item | Staging | Production |
|---|---|---|
| Trigger | push `staging` | tag `v*.*.*` + dispatch |
| Approval | opcional | **2 reviewers obrigatório** |
| Trivy | CRITICAL+HIGH | CRITICAL+HIGH+MEDIUM |
| Smoke duração | 10 req | 30s contínuo, tolera 2 falhas |
| Helm timeout | 8m | 10m |
| Change ticket | — | obrigatório (dispatch) ou tag |
| GitHub Release | — | **sim, com SBOM** |
| Concurrency | cancel-in-progress false | idem |
| Subject signature | `@refs/heads/staging` | `@refs/tags/v*` |

## Change management (A.8.32)

- **Tag** obrigatório em `v*.*.*` SemVer.
- **Change ticket** ID atrelado à imagem (Helm annotation).
- **2 reviewers** — segregação de deveres (A.5.3).
- **Release notes** auto-gerados — evidência de mudança.

## Rollback automático

- Smoke test falha → `helm rollback` para revisão anterior.
- Slack notifica.
- Pós-rollback: on-call triage, criar follow-up ticket.

Detalhe completo em [rollback-strategy.md](rollback-strategy.md).

## Decisões de design

1. **Approval no `build-sign-scan`** (antes de build) — não desperdiça
   build se reviewer rejeitar.
2. **Trivy MEDIUM** — reduz dívida prod.
3. **Smoke 30s contínuo** — detecta flakiness.
4. **Tolera 2 falhas em 30** — ~6.6% é threshold SLO.
5. **SBOM no Release** — evidência pública para parceiros.

## Controles ISO 27001

- A.5.3 — Segregation of duties (2 reviewers).
- A.8.9 — Configuration management.
- A.8.24 — Cryptography (sign).
- A.8.25 — Secure development.
- A.8.32 — Change management.
- A.5.26 — Response to incidents (rollback).

## Checklist pronto-para-código

- [ ] Workflow `cd-production-oci.yml` criado.
- [ ] Environment `production-oci` com 2 reviewers + tag restriction.
- [ ] Verify signature bloqueia deploy de imagem não assinada.
- [ ] Rollback auto testado em fire drill.
- [ ] Release com SBOM visível em `releases/`.
- [ ] Trivy MEDIUM adicionado (sem quebrar releases existentes).
