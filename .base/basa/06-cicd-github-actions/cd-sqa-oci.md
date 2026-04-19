# CD SQA — `cd-sqa-oci.yml`

**Arquiteto Principal:** Gustavo Armoa

## Objetivo

Deploy automático no OpenShift sqa a cada push em `develop`: build da
imagem UBI9, push para OCIR, `helm upgrade` no cluster, health check.

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
      - '.github/workflows/cd-sqa-oci.yml'
  workflow_dispatch:
```

## Concurrency

```yaml
concurrency:
  group: cd-sqa-oci
  cancel-in-progress: true
```

Deploy mais recente vence; evita race de dois deploys.

## Environment

```yaml
jobs:
  build-deploy:
    environment: sqa-oci
```

GitHub Environment `sqa-oci` não exige approval.

## Steps — esqueleto

```yaml
name: CD — SQA (OCI/OpenShift)

on:
  push:
    branches: [develop]
    paths:
      - 'krakend/**'
      - 'docker/Dockerfile.ubi9'
      - 'build/**'
      - 'k8s/helm/gateway/**'
      - 'tools/**'
      - '.github/workflows/cd-sqa-oci.yml'
  workflow_dispatch:

concurrency:
  group: cd-sqa-oci
  cancel-in-progress: true

env:
  OCP_NAMESPACE: gateway-sqa
  HELM_RELEASE: gateway
  IMAGE_NAME: gateway

jobs:
  build-deploy:
    name: Build & Deploy to OpenShift SQA
    runs-on: ubuntu-latest
    environment: sqa-oci
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
          token-exchange-url: https://auth.${{ secrets.OCI_REGION_SQA }}.oraclecloud.com/v1/oauth2/token

      # --- Get OCIR auth token ---
      - name: OCIR login
        env:
          OCIR_REPO: ${{ secrets.OCIR_REPO_SQA }}
        run: |
          oci raw-request --http-method POST \
            --target-uri "https://identity.${{ secrets.OCI_REGION_SQA }}.oraclecloud.com/20160918/auth-tokens" \
            --request-body '{"description":"gh-actions-sqa-${{ github.run_id }}"}' \
            | jq -r '.data.token' > /tmp/token
          cat /tmp/token | docker login "$(echo $OCIR_REPO | cut -d/ -f1)" \
            -u "${{ secrets.OCI_TENANCY_NAMESPACE }}/oke-ci" --password-stdin

      # --- Build UBI image ---
      - name: Build image
        env:
          TAG: sqa-${{ github.sha }}
          OCIR_REPO: ${{ secrets.OCIR_REPO_SQA }}
        run: |
          docker build \
            -f docker/Dockerfile.ubi9 \
            --build-arg ENV=sqa \
            --build-arg KRAKEND_VERSION=2.9.4 \
            --build-arg BUILD_SHA=${{ github.sha }} \
            -t "$OCIR_REPO/${{ env.IMAGE_NAME }}:$TAG" \
            -t "$OCIR_REPO/${{ env.IMAGE_NAME }}:sqa-latest" \
            .

      # --- Trivy scan (bloqueante em HIGH/CRITICAL fixable) ---
      - name: Trivy image scan
        uses: aquasecurity/trivy-action@master
        with:
          image-ref: ${{ secrets.OCIR_REPO_SQA }}/${{ env.IMAGE_NAME }}:sqa-${{ github.sha }}
          format: table
          exit-code: 1
          severity: CRITICAL,HIGH
          ignore-unfixed: true

      # --- Push OCIR ---
      - name: Push image
        env:
          TAG: sqa-${{ github.sha }}
          OCIR_REPO: ${{ secrets.OCIR_REPO_SQA }}
        run: |
          docker push "$OCIR_REPO/${{ env.IMAGE_NAME }}:$TAG"
          docker push "$OCIR_REPO/${{ env.IMAGE_NAME }}:sqa-latest"

      # --- Fetch kubeconfig do OCP sqa (armazenado em Vault) ---
      - name: Fetch OCP kubeconfig
        run: |
          mkdir -p ~/.kube
          oci secrets secret-bundle get \
            --secret-id ${{ secrets.OCP_KUBECONFIG_SECRET_OCID_SQA }} \
            --query 'data."secret-bundle-content".content' --raw-output \
            | base64 -d > ~/.kube/config
          chmod 600 ~/.kube/config

      # --- Helm deploy ---
      - uses: azure/setup-helm@v4
      - name: Helm upgrade
        env:
          TAG: sqa-${{ github.sha }}
          OCIR_REPO: ${{ secrets.OCIR_REPO_SQA }}
        run: |
          helm upgrade --install "${{ env.HELM_RELEASE }}" k8s/helm/gateway \
            -n "${{ env.OCP_NAMESPACE }}" --create-namespace \
            -f k8s/helm/gateway/values-oci-sqa.yaml \
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
            {"text":"✅ Gateway sqa-oci deploy OK — ${{ github.sha }}"}
        env:
          SLACK_WEBHOOK_URL: ${{ secrets.SLACK_WEBHOOK_URL }}

      - name: Notify Slack (failure)
        if: failure()
        uses: slackapi/slack-github-action@v1
        with:
          payload: |
            {"text":"🚨 Gateway sqa-oci deploy FAILED — ${{ github.sha }}"}
        env:
          SLACK_WEBHOOK_URL: ${{ secrets.SLACK_WEBHOOK_URL }}
```

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

1. **Trivy bloqueante** mesmo em sqa (detecta drift cedo).
2. **Smoke test via Route** — valida TLS + DNS + NetPol juntos.
3. **Kubeconfig do Vault**, não secret GitHub — rotacionável.
4. **Concurrency cancel** — deploy atual cancela anterior.
5. **Sem rollback auto em sqa** — falha fica visível; sqa fix manual.

## Controles ISO 27001

- A.8.9 — Configuration management.
- A.8.25 — Secure development life cycle.
- A.8.32 — Change management.

## Checklist pronto-para-código

- [ ] Workflow `.github/workflows/cd-sqa-oci.yml` criado.
- [ ] Secrets GitHub (`OCI_*`, `OCIR_REPO_SQA`, `OCP_KUBECONFIG_SECRET_OCID_SQA`) populados.
- [ ] Smoke Route retorna 200 em sqa.
- [ ] Slack notify ativo.
- [ ] Build cache configurado (opcional).
- [ ] Concurrency configurada.

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
