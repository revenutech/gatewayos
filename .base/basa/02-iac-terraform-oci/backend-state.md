# Backend State — Terraform

## Objetivo

Armazenar o state do Terraform do track Basa em **OCI Object Storage**,
criptografado, versionado e com locking, por env, sem credenciais
estáticas.

## Características

| Aspecto | Configuração |
|---|---|
| Backend | `backend "s3"` (S3 Compatibility do OCI Object Storage) em bucket `revenu-platform-tf-state-oci` |
| Locking | Native lockfile via `use_lockfile = true` (TF ≥ 1.10) |
| Encryption | `kms_key_id` do Vault (`key_tfstate`) |
| Versioning | Habilitado explicitamente |

## Bucket

Criado **uma vez, manual ou via root TF fora do repo**, não pelos envs.
Estrutura:

```
revenu-platform-tf-state-oci  (single bucket, region: sa-saopaulo-1)
├── gateway-basa/
│   ├── sqa/
│   │   └── terraform.tfstate
│   ├── uat/
│   │   └── terraform.tfstate
│   └── pro/
│       └── terraform.tfstate
└── ...  # outros módulos / projetos
```

Configuração:
- **Versioning:** Enabled.
- **Encryption:** `kms_key_id = <key_tfstate_ocid>` (Vault do env **pro**
  — todos os envs criptografam com a mesma key master para consistência;
  revisar em ADR se isolamento por env for exigido).
- **Lifecycle:** versões não-atuais expiram em 365 dias.
- **Public access:** Blocked.
- **Retention rule:** 30 dias (prevent accidental delete).

## Backend block — `shared/backend.tf` (partial)

```hcl
terraform {
  required_version = ">= 1.10.0"

  backend "s3" {
    bucket                      = "revenu-platform-tf-state-oci"
    key                         = "gateway-basa/{env}/terraform.tfstate"   # preenchido via -backend-config
    region                      = "sa-saopaulo-1"
    endpoints = {
      s3 = "https://<namespace>.compat.objectstorage.sa-saopaulo-1.oraclecloud.com"
    }
    skip_credentials_validation = true
    skip_region_validation      = true
    skip_requesting_account_id  = true
    skip_metadata_api_check     = true
    skip_s3_checksum            = true
    use_path_style              = true
    use_lockfile                = true   # TF 1.10+ — native lockfile via S3
  }
}
```

## Inicialização (por env)

```
cd deployment/infra/oci/environments/sqa
terraform init \
  -backend-config="bucket=revenu-platform-tf-state-oci" \
  -backend-config="key=gateway-basa/sqa/terraform.tfstate" \
  -backend-config="region=sa-saopaulo-1" \
  -backend-config="access_key=$OCI_S3_ACCESS_KEY" \
  -backend-config="secret_key=$OCI_S3_SECRET_KEY"
```

## Credenciais — fluxo sem keys estáticas (preferido)

OCI Object Storage suporta **S3 Compatibility API** + **Customer Secret
Keys**, mas keys são estáticas por natureza. Alternativas mais fortes:

1. **OIDC exchange → token temporário** (CI) — GitHub Actions troca OIDC
   token por session credential OCI; usa-se esse token para `oci os`
   (não Terraform s3 backend diretamente).
2. **Workaround CI:** um step roda `oci iam ... get-session-token`, exporta
   `AWS_ACCESS_KEY_ID`/`AWS_SECRET_ACCESS_KEY` (S3-compatible), Terraform
   usa.
3. **Desenvolvedor local:** `oci setup config` + customer secret key
   pessoal (isolado em `~/.oci/`).

V1 adota o workaround (2). Documentar em Fase 06.

## Locking

Com `use_lockfile = true` (Terraform 1.10+), lock é gravado como objeto
`{key}.tflock` no bucket. Concorrência segura, sem DynamoDB.

## Recovery de state

- **Corrupção:** restaurar versão anterior via `oci os object list-versions`
  + `get-object --version-id`. Runbook em Fase 08.
- **Drift:** `terraform refresh` seguido de plan.
- **Emergência:** `terraform force-unlock` **somente via runbook
  autorizado** (A.8.2 — acesso privilegiado).

## State em 3 buckets? (rejeitado)

Alternativa considerada: bucket separado por env (`tf-state-oci-sqa`,
etc.). Rejeitado — aumenta superfície IAM e complicação de lifecycle.
Um bucket com prefixos + IAM por prefix é o padrão da indústria.

## IAM no bucket

```
Allow dynamic-group gateway-ci-sqa-dg to manage object-family in compartment revenu-platform-shared where target.bucket.name='revenu-platform-tf-state-oci' and target.object.name like 'gateway-basa/sqa/*'
Allow dynamic-group gateway-ci-uat-dg to manage object-family in compartment revenu-platform-shared where target.bucket.name='revenu-platform-tf-state-oci' and target.object.name like 'gateway-basa/uat/*'
Allow dynamic-group gateway-ci-pro-dg to manage object-family in compartment revenu-platform-shared where target.bucket.name='revenu-platform-tf-state-oci' and target.object.name like 'gateway-basa/pro/*'
```

CI sqa não acessa state de pro. Princípio de menor privilégio (A.8.2).

## Decisões de design

1. **Bucket único, prefixo por env** — simplifica admin, IAM granular
   via path prefix.
2. **Encryption com key_tfstate** do Vault pro — centraliza rotação da
   key que protege todo o histórico de state.
3. **Versioning + Retention** — recovery de corrupção + proteção contra
   delete acidental.
4. **Lockfile nativo** — TF 1.10+ torna DynamoDB desnecessário.

## Controles ISO 27001

- A.8.2 — Privileged access (IAM granular por path).
- A.8.24 — Cryptography (KMS encryption at rest).
- A.5.33 — Protection of records (versioning + retention).
- A.12.3 — Backup (versioning provê recuperação).

## Checklist pronto-para-código

- [ ] Bucket criado via TF root ou manual, com versioning + KMS.
- [ ] Customer Secret Keys rotacionadas por env (CI consome via secret GH).
- [ ] IAM policies testadas (CI sqa tenta acessar state pro → negado).
- [ ] `use_lockfile = true` funciona (simular lock concorrente).
- [ ] Runbook de recovery escrito (referência em Fase 08).
