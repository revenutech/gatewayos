# Evidence Mapping — Onde coletar evidências em OCI/OpenShift

Para cada controle Annex A relevante ao track Basa, caminho concreto
para coletar evidência em auditoria — console path, comando `oc`/`oci
CLI`, ou artifact do repo.

## Como usar este documento

- Auditor pede evidência de controle X → consulta seção correspondente.
- Internal audit (A.5.35) → runbook trimestral colhe tudo automaticamente
  via script.
- Management Review (Cl. 9.3) → compila consolidação anual.

## A.5 — Organizational

### A.5.3 — Segregation of duties

- **GitHub:** Settings → Environments → `production-oci` → Required
  reviewers = 2.
- **Screenshot** mensal para `/compliance/evidences/{yyyy-mm}/env-reviewers.png`.
- **OCI:** Groups (dev/staging/prod separados).
  ```
  oci iam group list --compartment-id $TENANCY_OCID
  ```

### A.5.9 — Inventory of assets

- **OCI:** Cost Analysis ou Tag-based resource query.
  ```
  oci search resource structured-search --query-text \
    "query all resources where freeformTags.track = 'basa'" \
    --output json
  ```
- **Kubernetes:** inventário por cluster.
  ```
  oc get pods,svc,deploy,pvc,route -A -l platform.revenu/track=basa
  ```

### A.5.15 — Access control

- **OCI Policies:**
  ```
  oci iam policy list --compartment-id <gateway-basa-prod-compartment>
  ```
- **OCP RBAC:**
  ```
  oc get rolebindings,clusterrolebindings -A -o wide | grep -i gateway
  ```

### A.5.16 — Identity management

- **OCI Identity Domain:** Console → Identity & Security → Domains →
  Default → Users.
- **IdP GitHub:** Console → Identity Providers → GitHub-Actions →
  IdP Rules + Event logs.

### A.5.17 — Authentication information

- **OCI Vault:**
  ```
  oci vault secret list --compartment-id <compartment> --output table
  ```
- **ESO:**
  ```
  oc get clustersecretstore,externalsecret -A
  ```
- **Audit:** Vault access logs em OCI Audit
  (Console → Governance → Audit).

### A.5.21 — Supply chain

- **Cosign verify** imagem prod:
  ```
  cosign verify \
    --certificate-identity-regexp "^https://github.com/revenutech/revenu-platform-gateway/.github/workflows/cd-production-oci.yml@refs/tags/v" \
    --certificate-oidc-issuer "https://token.actions.githubusercontent.com" \
    gru.ocir.io/revenutech/gateway-basa-prod/gateway:v1.0.0
  ```
- **SBOM:**
  ```
  cosign verify-attestation --type cyclonedx ... | jq -r '.payload | @base64d | fromjson'
  ```
- **SLSA:** GitHub Attestations tab da release.

### A.5.23 — Cloud services

- **ADRs em** `.base/basa/00-foundation/adr-*.md`.
- **Contracts:** Oracle MSA + Red Hat MSA arquivados em secure repo
  (compliance/contracts/).

### A.5.28 — Evidence collection

- **compliance-oci.yml** daily reports em GitHub Actions Artifacts —
  retenção 7 anos (7×365 dias).
- **Console:** Actions → compliance-oci.yml → Daily run → Artifacts.

### A.5.29, A.5.30 — Business continuity

- **BCP doc** `.base/docs/operations/business-continuity-plan.md`.
- **DR runbook Basa:** `08-runbooks/dr-failover-cross-region.md`.
- **Drill logs:** `/compliance/evidences/drills/{yyyy-q}.md`.

### A.5.33 — Protection of records

- **Object Storage lifecycle:**
  ```
  oci os bucket get --name revenu-platform-log-archive-prod --output json | jq .lifecyclePolicyEtag
  ```
- **Versioning + Retention:**
  ```
  oci os bucket get-object-lifecycle-policy --bucket-name revenu-platform-tf-state-oci
  ```

### A.5.35 — Independent review

- **compliance-oci.yml** daily reports (retenção 7 anos).
- **Internal audit** procedure em `.base/docs/operations/internal-audit-procedure.md`.

### A.5.36 — Compliance with policies

- **Trivy SARIF** em GitHub Security tab.
- **audit.sh** output em CI logs.

## A.6 — People

### A.6.3 — Awareness, training

- Evidence: `/compliance/evidences/training/{yyyy}/oci-ocp-onboarding.md`.
- Signed acknowledgements (HR).

### A.6.7 — Remote working

- **OCI Bastion sessions:**
  ```
  oci bastion session list --bastion-id <bastion-ocid>
  ```
- **MFA enforcement** — Identity Domain Policy.

## A.7 — Physical

**Delegado OCI** — evidência via **certificações do fornecedor**:

- OCI: SOC 2 Type II, ISO 27001, ISO 27017, ISO 27018 (site Oracle
  trust portal).
- Red Hat: ISO 27001 do OpenShift build/support.
- **Download anual** no `/compliance/evidences/supplier-certs/{yyyy}/`.

## A.8 — Technological

### A.8.2 — Privileged access

- **Dynamic Groups:**
  ```
  oci iam dynamic-group list
  oci iam policy list --compartment-id <root>
  ```
- **SCC:**
  ```
  oc get scc restricted-v2 -o yaml
  ```

### A.8.4 — Access to source code

- **GitHub:** Settings → Branches → Protection rules.
- **CODEOWNERS:** `.github/CODEOWNERS` (não vazio para paths críticos).

### A.8.5 — Secure authentication

- **JWT config:**
  ```
  grep -r "RS256" krakend/partials/jwt_validator.tmpl
  grep -r "failed_jwk_key_cooldown" krakend/partials/jwt_validator.tmpl
  ```
- **OIDC federation:** OCI Console → Identity Domain → IdP GitHub →
  SAML/OIDC Metadata.

### A.8.8 — Vulnerability management

- **Trivy reports:** GitHub Actions artifact por build.
- **.trivyignore review:** PR history mostra reviews trimestrais.
- **Red Hat OVAL:** Trivy log mostra "Using Red Hat OVAL".

### A.8.9 — Configuration management

- **Helm release history:**
  ```
  helm history gateway -n gateway-prod --max 20
  ```
- **Terraform state:**
  ```
  oci os object list --bucket-name revenu-platform-tf-state-oci --prefix gateway-basa/prod/
  ```

### A.8.13 — Backup

- **etcd snapshots OCP:**
  ```
  oc get clustertasks -n openshift-etcd-operator
  oc debug node/<master> -- chroot /host /usr/local/bin/cluster-backup.sh /tmp/snap
  ```
- **tfstate versioning:**
  ```
  oci os object list-versions --bucket-name revenu-platform-tf-state-oci
  ```

### A.8.14 — Redundancy

- **Masters:**
  ```
  oc get nodes -l node-role.kubernetes.io/master -o wide
  ```
- **Workers multi-AD:**
  ```
  oc get nodes -l node-role.kubernetes.io/worker -o=jsonpath='{.items[*].metadata.labels.topology\.kubernetes\.io/zone}'
  ```
- **PDB:**
  ```
  oc get pdb -A -l app.kubernetes.io/name=gateway
  ```

### A.8.15 — Logging

- **OpenShift Logging (Loki):**
  Console → Observe → Logs (filter namespace gateway-prod).
- **OCI Audit:**
  Console → Governance → Audit.
- **VCN Flow logs:**
  Console → Logging → Log Groups → `gateway-basa-prod-vcn-flowlogs`.

### A.8.16 — Monitoring activities

- **Prometheus targets:**
  Console → Observe → Metrics → Targets (UP status).
- **Alertmanager:**
  ```
  oc get alertmanagerconfig -A
  ```
- **OCI Alarms:**
  ```
  oci monitoring alarm list --compartment-id <compartment>
  ```

### A.8.19 — Installation on operational systems

- **Immutable tags OCIR:**
  ```
  oci artifacts container repository get --repository-id <prod-repo-ocid> | jq .data.isImmutable
  ```
- **Policy-controller (quando ativo):**
  ```
  oc get clusterimagepolicies -o yaml
  ```

### A.8.20 — Networks security

- **NSGs:**
  ```
  oci network nsg list --compartment-id <compartment>
  ```
- **NetworkPolicies:**
  ```
  oc get networkpolicy -A -l platform.revenu/track=basa
  ```

### A.8.22 — Segregation of networks

- **Compartments:**
  ```
  oci iam compartment list --parent-compartment revenu-platform
  ```
- **Namespaces PSA labels:**
  ```
  oc get ns gateway-prod -o=jsonpath='{.metadata.labels}'
  ```

### A.8.24 — Cryptography

- **Vault HSM:**
  ```
  oci kms management vault get --vault-id <prod-vault-ocid> | jq .data."vault-type"
  ```
  (retorna "DEFAULT" ou "VIRTUAL_PRIVATE" — último é HSM).
- **TLS Routes:**
  ```
  oc get route -A -o jsonpath='{range .items[*]}{.metadata.name}{": "}{.spec.tls.termination}{"\n"}{end}'
  ```
- **FIPS status** (quando ativo):
  ```
  oc debug node/<any> -- chroot /host cat /proc/sys/crypto/fips_enabled
  ```

### A.8.25 — SDLC

- **CI workflows:** `.github/workflows/ci-oci.yml` + `compliance-oci.yml`.
- **Branch protection:** GitHub Settings → Branches.

### A.8.31 — Separation of environments

- **Compartments** + **Clusters** + **Namespaces** distintos.
  ```
  oci iam compartment list | grep gateway-basa-
  oc get ns | grep gateway-
  ```

### A.8.32 — Change management

- **Release history:**
  ```
  gh release list --repo revenutech/revenu-platform-gateway
  helm history gateway -n gateway-prod
  ```
- **Change tickets:** annotation no Deployment:
  ```
  oc get deploy gateway -n gateway-prod -o=jsonpath='{.metadata.annotations.platform\.revenu/change-ticket}'
  ```

### A.8.34 — Audit protection

- **Compliance Operator:**
  ```
  oc get scansettingbinding -n openshift-compliance
  oc get compliancesuite -n openshift-compliance
  oc get compliancecheckresult -n openshift-compliance | grep FAIL
  ```

## Internal audit script (sketch)

Script `tools/compliance-audit/collect-evidences.sh` (a criar em
Fase 08):

```
#!/usr/bin/env bash
# Coleta evidências para auditoria trimestral
OUT=/tmp/audit-evidence-$(date +%Y%m%d)
mkdir -p "$OUT"/{oci,ocp,github}

# OCI
oci iam policy list --compartment-id $C > "$OUT/oci/policies.json"
oci vault secret list --compartment-id $C > "$OUT/oci/secrets.json"
oci monitoring alarm list --compartment-id $C > "$OUT/oci/alarms.json"

# OCP
oc get netpol,psa,scc -A -o yaml > "$OUT/ocp/security.yaml"
helm history gateway -n gateway-prod --max 20 > "$OUT/ocp/helm-history.txt"
oc get compliancecheckresult > "$OUT/ocp/compliance-results.txt"

# GitHub
gh api repos/revenutech/revenu-platform-gateway/environments > "$OUT/github/environments.json"
gh release list > "$OUT/github/releases.txt"

tar -czf "$OUT.tar.gz" -C "$(dirname $OUT)" "$(basename $OUT)"
echo "Evidence pack: $OUT.tar.gz"
```

## Storage das evidências

- **Branch privada / repo separado** `compliance-evidences` com:
  ```
  /evidences/
    {yyyy}/
      {qq}/
        controls-matrix-snapshot.md
        audit-evidence-yyyymmdd.tar.gz
      drills/
      onboarding/
      management-review/
  ```
- **Criptografado em repouso** (Object Storage KMS em prod).
- **Retenção 7 anos** (A.5.33).

## Checklist pronto-para-código

- [ ] Cada controle no delta tem ao menos 1 comando / path concreto.
- [ ] `collect-evidences.sh` documentado em Fase 08.
- [ ] Repo `compliance-evidences` criado (ou equivalente secure).
- [ ] Retention 7 anos enforced.
- [ ] Auditor consegue coletar evidência sozinho seguindo este doc.
