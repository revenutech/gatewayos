# Matriz de Equivalência — GCP ↔ OCI / OpenShift / Red Hat

Todas as camadas do track GCP do Gateway, com equivalente direto em
OCI/OpenShift/RH, e nota sobre paridade funcional.

> Legenda paridade: 🟢 equivalente direto · 🟡 equivalente com ajuste ·
> 🔴 sem equivalente 1:1 (requer ADR ou substituto funcional).

## 1. Rede

| Aspecto | GCP | OCI / OpenShift | Paridade |
|---|---|---|---|
| Rede virtual | VPC `gateway-{env}-vpc` | OCI VCN `gateway-{env}-vcn` | 🟢 |
| Sub-redes | Subnet regional + secondary ranges (Pods/Services) | Subnets por AD + route tables | 🟡 Pods/Services CIDR definidos no install-config do OpenShift |
| Firewall | VPC Firewall Rules | Network Security Groups (NSG) + Security Lists | 🟢 |
| NAT egress | Cloud NAT | NAT Gateway | 🟢 |
| Peering | VPC Peering | Local/Remote Peering Gateway | 🟢 |
| DNS privado | Cloud DNS (private zones) | OCI DNS (private views) | 🟢 |

## 2. Compute / Orquestração

| Aspecto | GCP | OCI / OpenShift | Paridade |
|---|---|---|---|
| Cluster K8s | GKE (zonal dev / regional prod) | OpenShift on OCI (self-managed) | 🟡 OpenShift sempre HA control plane |
| Versão | GKE Regular channel | OCP stable channel (ex. 4.16) | 🟢 |
| Node pool | GKE node pool `e2-medium` / `e2-standard-4` | OpenShift MachineSet + Shape OCI (ex. `VM.Standard.E4.Flex`) | 🟢 |
| Autoscaler | GKE Cluster Autoscaler | OpenShift Machine Autoscaler (MAO) + Cluster Autoscaler operator | 🟢 |
| Release channel | REGULAR / STABLE | stable-4.x / fast-4.x | 🟢 |
| Binary Authorization | BinAuth (off hoje) | Sigstore policy-controller ou ACS admission | 🟡 |

## 3. Container Registry

| Aspecto | GCP | OCI / OpenShift | Paridade |
|---|---|---|---|
| Registry | Artifact Registry regional | OCI Container Registry (OCIR) regional | 🟢 |
| Imutabilidade tag | Config por repo (prod=true, dev=false) | OCIR: retention rules + image signing policy | 🟡 |
| Retenção | `keep_count=10` dev, maior em prod | Retention policy por repo | 🟢 |
| Scan | Artifact Registry Scanning (opcional) | Vulnerability scanning nativo OCIR + Trivy externo | 🟢 |
| Auth pull | Workload Identity (GSA→KSA) | Image Pull Secret (token OCIR) ou Dynamic Group + Instance Principal | 🟡 |

## 4. Secrets / KMS

| Aspecto | GCP | OCI / OpenShift | Paridade |
|---|---|---|---|
| KMS | Cloud KMS keyring | OCI Vault + Master Encryption Key | 🟢 |
| Secret store | Secret Manager | OCI Vault Secrets | 🟢 |
| Consumo em K8s | CSI Secret Store + WIF | External Secrets Operator (OCI provider) **ou** Secrets Store CSI + OCI provider | 🟡 |
| HSM | Cloud HSM (FIPS 140-2 L3) | OCI Vault HSM protection mode (FIPS 140-2 L3) | 🟢 |

## 5. DNS & TLS

| Aspecto | GCP | OCI / OpenShift | Paridade |
|---|---|---|---|
| Zona DNS | Cloud DNS público | OCI DNS público | 🟢 |
| Delegação | `allenty.io` → Cloud DNS | Subdomain delegada para OCI DNS (ex: `oci.allenty.io`) | 🟡 |
| TLS público | GKE ManagedCertificate (Google-managed) | cert-manager + Let's Encrypt (DNS01 via OCI DNS) | 🟡 |
| TLS interno | N/A (gclb termina TLS) | OpenShift service-ca (CA interna, rotaciona) | 🟢 |
| Redirect HTTP→HTTPS | Ingress annotation + FrontendConfig | OpenShift Route `insecureEdgeTerminationPolicy: Redirect` | 🟢 |

## 6. Ingress / Exposição

| Aspecto | GCP | OCI / OpenShift | Paridade |
|---|---|---|---|
| Ingress | GKE Ingress (GCLB) | OpenShift Route (HAProxy) | 🟡 Route é CRD OpenShift, não Ingress vanilla |
| LB externo | Google Cloud Load Balancer global | OCI Load Balancer (Flexible) | 🟢 |
| NEG / target | BackendConfig + NEG | Service + Route | 🟢 |
| WAF | Cloud Armor (opcional) | OCI WAF ou ACS (opcional) | 🟡 |

## 7. Observabilidade

| Aspecto | GCP | OCI / OpenShift | Paridade |
|---|---|---|---|
| Métricas | Cloud Monitoring + custom dashboards | OpenShift Monitoring (Prometheus Operator) + OCI Monitoring (bridge via OTel) | 🟢 |
| Logs | Cloud Logging | OpenShift Logging (Loki) + OCI Logging (via OTel exporter) | 🟢 |
| Tracing | Cloud Trace via OTel | Red Hat distributed tracing (Tempo / Jaeger) via OTel | 🟢 |
| Alerting | Cloud Monitoring Alerting | Alertmanager (OpenShift) + OCI Notifications | 🟢 |
| Dashboards | Grafana em GKE (recente) | Grafana Operator no OpenShift | 🟢 |

## 8. Imagem base

| Aspecto | GCP | OCI / OpenShift | Paridade |
|---|---|---|---|
| Base Docker | Alpine / Debian via `devopsfaith/krakend:2.9.4` | UBI9-minimal + build KrakenD CE from source | 🟡 |
| User non-root | `USER 1000` | `USER 1001` (convenção OpenShift random UID) | 🟢 |
| FIPS | N/A | UBI9 + RHCOS em FIPS mode (opcional) | 🟢 |
| Cert | N/A | Red Hat Container Certification (labels + license) | 🟢 |

## 9. IAM / Auth para CI/CD

| Aspecto | GCP | OCI / OpenShift | Paridade |
|---|---|---|---|
| Auth de workflow | GCP Workload Identity Federation (OIDC) | OCI OIDC Federation (GitHub → Domain Identity Provider) | 🟡 OCI OIDC federation é mais recente, menos docs |
| Identity K8s | Workload Identity GSA↔KSA | OCI Instance Principal / Resource Principal + RoleBinding | 🟡 |
| Keys estáticas | Proibido hoje | Proibido no plano (apenas OIDC) | 🟢 |

## 10. Supply Chain

| Aspecto | GCP | OCI / OpenShift | Paridade |
|---|---|---|---|
| Assinatura | Cosign keyless (GH OIDC) | Cosign keyless (mesmo modelo) + opcional Red Hat Trusted Artifact Signer | 🟢 |
| SBOM | CycloneDX via Trivy | CycloneDX via Trivy | 🟢 |
| Scan | Trivy (CRITICAL/HIGH) | Trivy + opcional Red Hat ACS | 🟢 |
| Policy / admission | N/A hoje | Sigstore policy-controller ou ACS admission controller | 🟡 |
| Provenance SLSA | Parcial (build metadata) | SLSA Level 3 via build isolado + OIDC | 🟡 |

## 11. CI/CD

| Aspecto | GCP | OCI / OpenShift | Paridade |
|---|---|---|---|
| Orquestrador | GitHub Actions | GitHub Actions | 🟢 |
| Workflows atuais | `ci.yml`, `cd-dev-gcp.yml`, `cd-staging-gcp.yml`, `cd-production-gcp.yml`, `compliance.yml` | `ci-oci.yml`, `cd-dev-oci.yml`, `cd-staging-oci.yml`, `cd-production-oci.yml`, `compliance-oci.yml` | 🟢 |
| Approval gate | `environment: production` | `environment: production-oci` | 🟢 |
| Rollback | `helm rollback gateway 0` | idem | 🟢 |

## 12. Estado Terraform

| Aspecto | GCP | OCI / OpenShift | Paridade |
|---|---|---|---|
| Backend | GCS bucket `revenu-platform-tf-state` | OCI Object Storage bucket `revenu-platform-tf-state-oci` | 🟢 |
| Locking | GCS nativo (beta) | Object Storage + DynamoDB-like? → usar lockfile via Object Storage + OCI-native lock | 🟡 |
| Prefixo | `gateway/{env}` | `gateway-basa/{env}` | 🟢 |

## 13. ISO 27001

| Aspecto | GCP (atual) | OCI / OpenShift (Basa) | Paridade |
|---|---|---|---|
| ISMS Scope | Inclui GKE + Artifact Registry + Cloud KMS | Adicionar OpenShift + OCIR + OCI Vault (delta em 07) | 🟡 |
| Controls Matrix | 93 controles mapeados com evidências GCP | Delta com evidências OCI/OpenShift | 🟡 |
| Risk register | 15 riscos atuais | +6 riscos macro (B-R01..R06) | 🟡 |
| Annex A.8.31 | Separação de envs GCP | Separação de envs OCI (projetos / compartments) | 🟢 |

## Gaps reconhecidos

- **🔴 Zero-trust / service mesh** — track GCP não usa; Basa também não na v1. Reavaliar pós-cutover.
- **🔴 Multi-cloud observability federation** — não há plano de unir métricas dos dois tracks. Fica explicitamente fora do escopo.
- **🟡 Backup de etcd** — OpenShift fornece nativo (`cluster-backup.sh`); runbook em 08.
