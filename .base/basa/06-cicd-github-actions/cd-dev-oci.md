# CD Dev — `cd-dev-oci.yml`

## Objetivo

Deploy automático no OpenShift dev a cada push em `develop`: build da
imagem UBI9, push para OCIR, `helm upgrade` no cluster, health check.
Paridade com `cd-dev-gcp.yml`.

## Trigger

```yaml
on:
  push:
    branches: [develop]
    paths:
      - 'krakend/**'
      - 'docker/Dockerfile.ubi9'
      - 'build/**'
      - 'k8s/helm/gateway/**'
      - 'tools/**'
      - '.github/workflows/cd-dev-oci.yml'
  workflow_dispatch:
```

## Concurrency

```yaml
concurrency:
  group: cd-dev-oci
  cancel-in-progress: true
```

Deploy mais recente vence; evita race de dois deploys.

## Environment

```yaml
jobs:
  build-deploy:
    environment: dev-oci
```

GitHub Environment `dev-oci` não exige approval.

## Steps — esqueleto

```yaml
name: CD — Dev (OCI/OpenShift)

on:
  push:
    branches: [develop]
    paths:
      - 'krakend/**'
      - 'docker/Dockerfile.ubi9'
      - 'build/**'
      - 'k8s/helm/gateway/**'
      - 'tools/**'
      - '.github/workflows/cd-dev-oci.yml'
  workflow_dispatch:

concurrency:
  group: cd-dev-oci
  cancel-in-progress: true

env:
  OCP_NAMESPACE: gateway-dev
  HELM_RELEASE: gateway
  IMAGE_NAME: gateway

jobs:
  build-deploy:
    name: Build & Deploy to OpenShift Dev
    runs-on: ubuntu-latest
    environment: dev-oci
    permissions:
      contents: read
      id-token: write
    steps:
      - uses: actions/checkout@v4

      # --- Auth OCI ---
      - name: Configure OCI CLI (OIDC)
        uses: oracle-actions/configure-oci-cli@v1.3.2
        with:
          tenancy-ocid: ${{ secrets.OCI_TENANCY_OCID }}
          token-exchange-url: https://auth.${{ secrets.OCI_REGION_DEV }}.oraclecloud.com/v1/oauth2/token

      # --- Get OCIR auth token ---
      - name: OCIR login
        env:
          OCIR_REPO: ${{ secrets.OCIR_REPO_DEV }}
        run: |
          oci raw-request --http-method POST \
            --target-uri "https://identity.${{ secrets.OCI_REGION_DEV }}.oraclecloud.com/20160918/auth-tokens" \
            --request-body '{"description":"gh-actions-dev-${{ github.run_id }}"}' \
            | jq -r '.data.token' > /tmp/token
          cat /tmp/token | docker login "$(echo $OCIR_REPO | cut -d/ -f1)" \
            -u "${{ secrets.OCI_TENANCY_NAMESPACE }}/oke-ci" --password-stdin

      # --- Build UBI image ---
      - name: Build image
        env:
          TAG: dev-${{ github.sha }}
          OCIR_REPO: ${{ secrets.OCIR_REPO_DEV }}
        run: |
          docker build \
            -f docker/Dockerfile.ubi9 \
            --build-arg ENV=dev \
            --build-arg KRAKEND_VERSION=2.9.4 \
            --build-arg BUILD_SHA=${{ github.sha }} \
            -t "$OCIR_REPO/${{ env.IMAGE_NAME }}:$TAG" \
            -t "$OCIR_REPO/${{ env.IMAGE_NAME }}:dev-latest" \
            .

      # --- Trivy scan (bloqueante em HIGH/CRITICAL fixable) ---
      - name: Trivy image scan
        uses: aquasecurity/trivy-action@master
        with:
          image-ref: ${{ secrets.OCIR_REPO_DEV }}/${{ env.IMAGE_NAME }}:dev-${{ github.sha }}
          format: table
          exit-code: 1
          severity: CRITICAL,HIGH
          ignore-unfixed: true

      # --- Push OCIR ---
      - name: Push image
        env:
          TAG: dev-${{ github.sha }}
          OCIR_REPO: ${{ secrets.OCIR_REPO_DEV }}
        run: |
          docker push "$OCIR_REPO/${{ env.IMAGE_NAME }}:$TAG"
          docker push "$OCIR_REPO/${{ env.IMAGE_NAME }}:dev-latest"

      # --- Fetch kubeconfig do OCP dev (armazenado em Vault) ---
      - name: Fetch OCP kubeconfig
        run: |
          mkdir -p ~/.kube
          oci secrets secret-bundle get \
            --secret-id ${{ secrets.OCP_KUBECONFIG_SECRET_OCID_DEV }} \
            --query 'data."secret-bundle-content".content' --raw-output \
            | base64 -d > ~/.kube/config
          chmod 600 ~/.kube/config

      # --- Helm deploy ---
      - uses: azure/setup-helm@v4
      - name: Helm upgrade
        env:
          TAG: dev-${{ github.sha }}
          OCIR_REPO: ${{ secrets.OCIR_REPO_DEV }}
        run: |
          helm upgrade --install "${{ env.HELM_RELEASE }}" k8s/helm/gateway \
            -n "${{ env.OCP_NAMESPACE }}" --create-namespace \
            -f k8s/helm/gateway/values-oci-dev.yaml \
            --set image.repository="$OCIR_REPO/${{ env.IMAGE_NAME }}" \
            --set image.tag="$TAG" \
            --set configHash=${{ github.sha }} \
            --wait --timeout 6m

      # --- Health check ---
      - name: Health check
        run: |
          for i in $(seq 1 20); do
            PHASE=$(kubectl -n "${{ env.OCP_NAMESPACE }}" \
              get pods -l app.kubernetes.io/name=gateway \
              -o jsonpath='{.items[0].status.phase}' 2>/dev/null || echo Pending)
            echo "Attempt $i — phase=$PHASE"
            [ "$PHASE" = "Running" ] && exit 0
            sleep 10
          done
          echo "Pod never became Ready"
          kubectl -n "${{ env.OCP_NAMESPACE }}" describe pods -l app.kubernetes.io/name=gateway
          kubectl -n "${{ env.OCP_NAMESPACE }}" logs -l app.kubernetes.io/name=gateway --tail=100
          exit 1

      # --- Smoke test via Route ---
      - name: Smoke via Route
        run: |
          HOST=$(kubectl -n "${{ env.OCP_NAMESPACE }}" \
            get route gateway -o jsonpath='{.spec.host}')
          for i in $(seq 1 10); do
            if curl -fsS --max-time 10 "https://${HOST}/__health"; then
              echo "Route OK"
              exit 0
            fi
            sleep 5
          done
          echo "Route never responded 200"
          exit 1

      # --- Notify ---
      - name: Notify Slack (success)
        if: success()
        uses: slackapi/slack-github-action@v1
        with:
          payload: |
            {"text":"✅ Gateway dev-oci deploy OK — ${{ github.sha }}"}
        env:
          SLACK_WEBHOOK_URL: ${{ secrets.SLACK_WEBHOOK_URL }}

      - name: Notify Slack (failure)
        if: failure()
        uses: slackapi/slack-github-action@v1
        with:
          payload: |
            {"text":"🚨 Gateway dev-oci deploy FAILED — ${{ github.sha }}"}
        env:
          SLACK_WEBHOOK_URL: ${{ secrets.SLACK_WEBHOOK_URL }}
```

## Diferenças vs `cd-dev-gcp.yml`

| Item | GCP | Basa |
|---|---|---|
| Auth | `google-github-actions/auth@v2` + WIF | `oracle-actions/configure-oci-cli` + OIDC |
| Registry login | `gcloud auth configure-docker` | `docker login` com auth token OCIR |
| Cluster creds | `get-gke-credentials` | `oci secrets secret-bundle get` (kubeconfig do Vault) |
| Image path | `${AR_REPO}/gateway` | `${OCIR_REPO}/gateway` |
| Health check | espera `status.phase=Running` | idem + smoke HTTP via Route |
| Rollback auto | não (dev é permissivo) | idem |

## Tempo estimado

- Build: ~3 min (sem cache).
- Trivy scan: ~1 min.
- Push: ~30s.
- Helm deploy + health: ~2 min.
- **Total:** ~6–8 min por deploy.

## Optimizações

- **Build cache** via `docker buildx` + `--cache-to type=registry`.
- **Pré-build** do stage `krakend-builder` cached separado.
- **`dockerfile-ubi-build` do CI** reutilizando mesma layer.

## Decisões de design

1. **Trivy bloqueante** mesmo em dev (detecta drift cedo).
2. **Smoke test via Route** — valida TLS + DNS + NetPol juntos.
3. **Kubeconfig do Vault**, não secret GitHub — rotacionável.
4. **Concurrency cancel** — deploy atual cancela anterior.
5. **Sem rollback auto em dev** — falha fica visível; dev fix manual.

## Controles ISO 27001

- A.8.9 — Configuration management.
- A.8.25 — Secure development life cycle.
- A.8.32 — Change management.

## Checklist pronto-para-código

- [ ] Workflow `.github/workflows/cd-dev-oci.yml` criado.
- [ ] Secrets GitHub (`OCI_*`, `OCIR_REPO_DEV`, `OCP_KUBECONFIG_SECRET_OCID_DEV`) populados.
- [ ] Smoke Route retorna 200 em dev.
- [ ] Slack notify ativo.
- [ ] Build cache configurado (opcional).
- [ ] Concurrency configurada.
