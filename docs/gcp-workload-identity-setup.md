# GCP Workload Identity Federation Setup

## Overview

Este documento descreve a configuração necessária de Workload Identity Federation para autenticação segura do GitHub Actions com GCP, eliminando a necessidade de chaves JSON de service account.

## Status Atual

| Ambiente   | Projeto GCP                    | Status WI Pool        |
|------------|--------------------------------|-----------------------|
| Dev        | revenu-gateway-dev             | **Não configurado**   |
| Staging    | revenu-gateway-staging         | A verificar           |
| Production | revenu-gateway-production      | A verificar           |

## Por que Workload Identity Federation?

### Problemas com Chaves JSON (método atual)
- **Risco de vazamento**: Chaves são credenciais de longa duração
- **Rotação manual**: Precisam ser rotacionadas periodicamente
- **Gestão complexa**: Múltiplas chaves para múltiplos ambientes
- **Auditoria limitada**: Difícil rastrear uso específico

### Benefícios do Workload Identity Federation
- **Sem credenciais estáticas**: Tokens são gerados dinamicamente
- **Escopo limitado**: Apenas workflows do repositório específico podem autenticar
- **Auditoria completa**: Logs detalhados de cada autenticação
- **Zero rotação**: Não há chaves para gerenciar

## Configuração Necessária

### Pré-requisitos
- Permissão `iam.workloadIdentityPools.create` no projeto GCP
- Acesso de administrador ao repositório GitHub

### 1. Criar Workload Identity Pool (por ambiente)

```bash
# Ambiente: Dev
PROJECT_ID="revenu-gateway-dev"
POOL_NAME="github-actions-pool"

gcloud iam workload-identity-pools create "$POOL_NAME" \
  --project="$PROJECT_ID" \
  --location="global" \
  --display-name="GitHub Actions Pool"
```

### 2. Criar Provider OIDC

```bash
REPO="revenutech/gateway"

gcloud iam workload-identity-pools providers create-oidc "github-provider" \
  --project="$PROJECT_ID" \
  --location="global" \
  --workload-identity-pool="$POOL_NAME" \
  --display-name="GitHub Provider" \
  --attribute-mapping="google.subject=assertion.sub,attribute.actor=assertion.actor,attribute.repository=assertion.repository" \
  --issuer-uri="https://token.actions.githubusercontent.com" \
  --attribute-condition="assertion.repository=='$REPO'"
```

### 3. Vincular Service Account

```bash
SA_EMAIL="gateway-ci-dev@revenu-gateway-dev.iam.gserviceaccount.com"
PROJECT_NUMBER=$(gcloud projects describe "$PROJECT_ID" --format="value(projectNumber)")

gcloud iam service-accounts add-iam-policy-binding "$SA_EMAIL" \
  --project="$PROJECT_ID" \
  --role="roles/iam.workloadIdentityUser" \
  --member="principalSet://iam.googleapis.com/projects/$PROJECT_NUMBER/locations/global/workloadIdentityPools/$POOL_NAME/attribute.repository/$REPO"
```

### 4. Obter Workload Identity Provider Path

```bash
gcloud iam workload-identity-pools providers describe "github-provider" \
  --project="$PROJECT_ID" \
  --location="global" \
  --workload-identity-pool="$POOL_NAME" \
  --format="value(name)"
```

O output será algo como:
```
projects/123456789/locations/global/workloadIdentityPools/github-actions-pool/providers/github-provider
```

### 5. Configurar Secrets no GitHub

Para cada ambiente (dev, staging, production):

| Secret Name                           | Valor                                                    |
|---------------------------------------|----------------------------------------------------------|
| `GCP_WORKLOAD_IDENTITY_PROVIDER_DEV`  | `projects/<num>/locations/global/workloadIdentityPools/github-actions-pool/providers/github-provider` |
| `GCP_SERVICE_ACCOUNT_DEV`             | `gateway-ci-dev@revenu-gateway-dev.iam.gserviceaccount.com` |

## Configuração por Ambiente

### Dev
```bash
PROJECT_ID="revenu-gateway-dev"
SA_EMAIL="gateway-ci-dev@revenu-gateway-dev.iam.gserviceaccount.com"
```

### Staging
```bash
PROJECT_ID="revenu-gateway-staging"
SA_EMAIL="gateway-ci-staging@revenu-gateway-staging.iam.gserviceaccount.com"
```

### Production
```bash
PROJECT_ID="revenu-gateway-production"
SA_EMAIL="gateway-ci-prod@revenu-gateway-production.iam.gserviceaccount.com"
```

## Script de Automação

Um script completo está disponível em `tools/setup-workload-identity.sh` para automatizar todo o processo.

## Solução Temporária (Chave JSON)

Enquanto o Workload Identity não está configurado, estamos usando chaves JSON:

1. Criar chave JSON:
```bash
gcloud iam service-accounts keys create key.json \
  --iam-account=gateway-ci-dev@revenu-gateway-dev.iam.gserviceaccount.com
```

2. Configurar secret no GitHub:
```bash
gh secret set GCP_SA_KEY_DEV < key.json
```

3. Modificar workflow para usar `credentials_json` em vez de `workload_identity_provider`

**IMPORTANTE**: Remover chaves JSON assim que Workload Identity estiver configurado.

## Referências

- [Workload Identity Federation](https://cloud.google.com/iam/docs/workload-identity-federation)
- [GitHub Actions OIDC](https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/about-security-hardening-with-openid-connect)
- [google-github-actions/auth](https://github.com/google-github-actions/auth)

---
*Documento criado em: 2026-04-08*
*Pendente: Solicitar permissões de admin para criar Workload Identity Pools*
