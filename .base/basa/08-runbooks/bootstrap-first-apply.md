# Runbook — Bootstrap First Apply (OCI/OpenShift)

## Objetivo

Provisionar, do zero, todo o track Basa em um env novo (sqa / uat /
pro) — do Terraform ao cluster OpenShift pronto para receber o Gateway.

## Owner / Backup

- **Owner:** SRE Lead.
- **Backup:** Platform Owner.
- **Aprovador (pro):** ISO Lead + Platform Owner.

## Trigger

- Criar ambiente OCI novo.
- Rebuild completo após DR catastrófico (cross-region).
- Criar env sandbox novo.

## Pre-checks

- [ ] OCI tenancy com quotas suficientes (compute, LB, storage, KMS).
- [ ] Red Hat pull secret disponível em secure vault (não no repo).
- [ ] SSH key pública do operador pronta.
- [ ] Acesso ao bucket `revenu-platform-tf-state-oci` (IAM policies
      aplicadas — Fase 02 `backend-state.md`).
- [ ] Domain `oci.allenty.io` (ou subzone `{env}.oci.allenty.io`) —
      pronto para delegação NS.
- [ ] Secrets GitHub populados (nome conforme Fase 00
      `naming-conventions.md`).
- [ ] Branch `develop`/`uat`/`main` correto e CI verde.
- [ ] Compartment `gateway-basa-{env}` já existe no tenancy.
- [ ] Ticket de mudança aberto (pro).

## Procedimento

### 1. Setup local do operador

```
export OCI_CLI_TENANCY=$OCI_TENANCY_OCID
export OCI_CLI_REGION=sa-saopaulo-1
oci setup config                           # one-time
oci iam region list                        # smoke test auth
```

### 2. Criar namespace de compartment + tag namespace (1× tenant)

```
oci iam tag-namespace create \
  --compartment-id $TENANCY_OCID \
  --name revenu-platform \
  --description "Revenu Platform governance tags"

# Criar tags (app, track, env, managed-by, iso27001, owner, cost-center)
# Detalhe em 02-iac-terraform-oci/variables-tags.md
```

Só necessário na primeira vez por tenant.

### 3. Apply Terraform — ordem explícita

**Cada env em sua pasta:**

```
cd deployment/infra/oci/environments/sqa

terraform init \
  -backend-config="bucket=revenu-platform-tf-state-oci" \
  -backend-config="key=gateway-basa/sqa/terraform.tfstate" \
  -backend-config="region=sa-saopaulo-1" \
  -backend-config="endpoints={s3=\"https://<NS>.compat.objectstorage.sa-saopaulo-1.oraclecloud.com\"}" \
  -backend-config="access_key=$OCI_S3_ACCESS_KEY" \
  -backend-config="secret_key=$OCI_S3_SECRET_KEY"
```

**Ordem de apply:**

```
# 1. KMS Vault primeiro (outros módulos referenciam)
terraform apply -target=module.vault

# 2. Rede + registry + DNS em paralelo
terraform apply \
  -target=module.vcn \
  -target=module.ocir \
  -target=module.dns

# PAUSA — delegar NS no provedor DNS da zona pai allenty.io
#   (passo 4 abaixo)

# 3. Popular secrets Vault
#   (passo 5 abaixo)

# 4. OpenShift — demora 35–60 min
terraform apply -target=module.openshift

# 5. Bastion + monitoring
terraform apply -target=module.bastion -target=module.monitoring

# 6. Reconciliação final
terraform apply
```

### 4. Delegação NS (manual, uma vez por env)

Na zona pai `allenty.io`:

```
{env}.oci.allenty.io.   86400  IN  NS  ns1.p{nn}.dns.oraclecloud.net.
{env}.oci.allenty.io.   86400  IN  NS  ns2.p{nn}.dns.oraclecloud.net.
{env}.oci.allenty.io.   86400  IN  NS  ns3.p{nn}.dns.oraclecloud.net.
{env}.oci.allenty.io.   86400  IN  NS  ns4.p{nn}.dns.oraclecloud.net.
```

NS exatos de `terraform output zone_nameservers`.

**Validar:**
```
dig +short NS {env}.oci.allenty.io
```

### 5. Popular secrets no Vault

Antes do install OpenShift:

```
# Red Hat pull secret
oci vault secret create-base64 \
  --compartment-id $COMPARTMENT \
  --secret-name gateway-basa-{env}-rh-pullsecret \
  --vault-id $VAULT_OCID \
  --key-id $KEY_APP_OCID \
  --secret-content-content "$(base64 -w 0 /path/to/pull-secret.json)"

# OCIR push token (CI)
# Gerar via oci iam auth-token create, gravar em Vault
```

### 6. Aguardar OpenShift install

```
tail -f deployment/infra/oci/environments/sqa/.terraform/openshift-install.log
# Install completo: ~45 min
```

Quando `openshift-install wait-for install-complete` retornar:

```
export KUBECONFIG=$(terraform output -raw kubeconfig_path)
oc whoami                           # kube:admin
oc get nodes                        # todos Ready
oc get co                           # todos Available=True
```

### 7. Pós-install — aplicar manifests bootstrap

```
# Habilitar User Workload Monitoring
oc apply -f - <<EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: cluster-monitoring-config
  namespace: openshift-monitoring
data:
  config.yaml: |
    enableUserWorkload: true
EOF

# Namespace gateway-{env}
oc create namespace gateway-{env}
oc label namespace gateway-{env} \
  pod-security.kubernetes.io/enforce=restricted \
  platform.revenu/env={env} \
  platform.revenu/track=basa

# MachineAutoscaler + ClusterAutoscaler
oc apply -f k8s/manifests-openshift/bootstrap/autoscaler-*.yaml

# External Secrets Operator
oc apply -f k8s/manifests-openshift/bootstrap/eso-subscription.yaml
# aguardar operator Ready
oc apply -f k8s/manifests-openshift/bootstrap/clustersecretstore-oci.yaml

# cert-manager Operator
oc apply -f k8s/manifests-openshift/bootstrap/cert-manager-subscription.yaml
oc apply -f k8s/manifests-openshift/bootstrap/clusterissuer-letsencrypt.yaml

# Logging + Loki operators
oc apply -f k8s/manifests-openshift/bootstrap/logging-operators.yaml
oc apply -f k8s/manifests-openshift/bootstrap/lokistack.yaml
oc apply -f k8s/manifests-openshift/bootstrap/clusterlogging.yaml
oc apply -f k8s/manifests-openshift/bootstrap/clusterlogforwarder.yaml

# OTel Operator + collectors
oc apply -f k8s/manifests-openshift/bootstrap/otel-operator.yaml
oc apply -f k8s/manifests-openshift/bootstrap/otel-collectors.yaml

# Grafana Operator + instance + datasources
oc apply -f k8s/manifests-openshift/bootstrap/grafana-operator.yaml
oc apply -f k8s/manifests-openshift/bootstrap/grafana-instance.yaml
oc apply -f k8s/manifests-openshift/bootstrap/grafana-datasources.yaml

# Compliance Operator
oc apply -f k8s/manifests-openshift/bootstrap/compliance-operator.yaml
oc apply -f k8s/manifests-openshift/bootstrap/scansettingbinding.yaml
```

### 8. Persistir kubeconfig no Vault

CI consome kubeconfig do Vault (Fase 06):

```
oci vault secret create-base64 \
  --compartment-id $COMPARTMENT \
  --secret-name gateway-basa-{env}-kubeconfig \
  --vault-id $VAULT_OCID \
  --key-id $KEY_APP_OCID \
  --secret-content-content "$(base64 -w 0 < $KUBECONFIG)"
```

Atualizar `OCP_KUBECONFIG_SECRET_OCID_{ENV}` nos secrets do GitHub.

### 9. First deploy via CD pipeline

```
git checkout develop
git push origin develop     # trigger cd-sqa-oci.yml
```

Validar em Actions → CD — SQA (OCI/OpenShift) → verde.

## Pós-check

- [ ] `oc get pods -A | grep -vE 'Running|Completed'` — nenhum abnormal.
- [ ] `oc get co` — todos `Available=True, Progressing=False, Degraded=False`.
- [ ] Route `gateway.{env}.oci.allenty.io` retorna 200 em `/__health`.
- [ ] Métricas Gateway visíveis em Console → Observe → Metrics.
- [ ] Logs Gateway visíveis em Grafana Loki.
- [ ] Alertmanager routes drill (enviar alerta fake).

## Evidência a gerar

- Commit ID do apply bem-sucedido.
- `terraform output -json` → salvar em
  `/compliance/evidences/runbooks/{yyyy-mm-dd}-bootstrap-{env}.json`.
- Screenshot dashboard Grafana operacional.
- Output de `oc get co`.

## Escalação

- Install OpenShift falha > 60 min → OCI Support + Red Hat Support.
- Terraform apply falha → Platform Owner.
- DNS delegation não propaga 24h → network admin da zona pai.

## Drill

**Não aplicável** — é um procedimento one-time. Alternativa: recriar env
sandbox trimestralmente.

## Relacionado

- Fase 02 — IaC modules.
- Fase 03 — K8s/OpenShift manifests.
- Fase 04 — Observability operators.
- Fase 05 — Secrets flow.
- Fase 06 — CD pipelines.

## Changelog

- 2026-04-17 — v1 inicial.
