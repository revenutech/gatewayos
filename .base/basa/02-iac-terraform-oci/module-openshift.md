# Module — OpenShift (on OCI)

## Objetivo

Provisionar um cluster **Red Hat OpenShift Container Platform (OCP)** sobre
OCI, usando o **OpenShift Installer em modo UPI (User Provisioned
Infrastructure)** orquestrado via Terraform + OCI SDK. Equivalente ao
módulo `gke` do track GCP.

> **Nota:** Na data da ADR-001 (2026-04-17), **Oracle e Red Hat mantêm
> parceria oficial** com imagens RHCOS publicadas no OCI Marketplace. O
> fluxo abaixo é o modelo "assisted UPI" — Terraform cria compute/LB/DNS,
> o Installer só gera ignition configs e valida o cluster.

## Equivalência GCP ↔ Basa

| GCP | OCI + OpenShift |
|---|---|
| `google_container_cluster` (GKE control plane managed) | `oci_core_instance` × 3 (master nodes) + `oci_core_instance` × N (workers) criados pelo Terraform + Installer |
| `google_container_node_pool` | `MachineSet` CR (pós-install, gerenciado pelo MAO) |
| Workload Identity | **Service Account + OIDC issuer** do OCP + federação com OCI via Resource Principal |
| Release channel (GKE) | OCP channel (`stable-4.16`) |
| Binary Authorization | Sigstore policy-controller (Fase 05) |
| Network Policy = CALICO | OVN-Kubernetes (default OCP) |

## Abordagem — UPI assistido por Terraform

O OpenShift Installer não tem provedor nativo OCI. Fluxo:

1. **Terraform** — cria:
   - Compute instances para bootstrap + 3 masters + 3 workers iniciais.
   - Load Balancer OCI para API (6443) e Ingress (80/443).
   - DNS records (via `module-dns`).
   - Placement groups / fault domains para HA.
2. **OpenShift Installer** — gera `install-config.yaml` + ignition configs
   (`bootstrap.ign`, `master.ign`, `worker.ign`) em `cluster_dir`.
3. **Ignition configs** subidos para Object Storage (bucket temporário
   `gateway-basa-{env}-ignition`) com presigned URLs.
4. **Compute instances** bootam com `user_data` apontando para a ignition
   config correspondente via URL presigned.
5. **Bootstrap** node levanta cluster; depois é destruído automaticamente.
6. **Pós-install** — criar `MachineSet` adicional para worker autoscaling.

## Inputs

```hcl
variable "compartment_id"    { type = string }
variable "environment"       { type = string }
variable "region"            { type = string }
variable "cluster_name"      { type = string }                    # gateway-basa-dev-ocp
variable "vcn_id"            { type = string }
variable "subnet_app_id"     { type = string }
variable "subnet_lb_id"      { type = string }
variable "nsg_nodes_id"      { type = string }
variable "nsg_api_id"        { type = string }
variable "nsg_lb_id"         { type = string }
variable "pod_cidr"          { type = string }
variable "service_cidr"      { type = string }
variable "pull_secret"       { type = string, sensitive = true }  # Red Hat pull secret
variable "ssh_pub_key"       { type = string }
variable "base_domain"       { type = string }                    # ex: oci.allenty.io
variable "master_shape"      { type = string, default = "VM.Standard.E4.Flex" }
variable "master_ocpus"      { type = number, default = 4 }
variable "master_memory_gb"  { type = number, default = 16 }
variable "worker_shape"      { type = string, default = "VM.Standard.E4.Flex" }
variable "worker_ocpus"      { type = number, default = 2 }       # dev
variable "worker_memory_gb"  { type = number, default = 8 }
variable "worker_count"      { type = number, default = 2 }       # dev=2, staging=3, prod=3+
variable "fips_enabled"      { type = bool, default = false }
variable "ocp_version"       { type = string, default = "4.16.20" }
variable "defined_tags"      { type = map(string) }
variable "kms_key_id"        { type = string }                    # módulo vault — criptografia de boot volumes
```

## Recursos principais

| Nome TF | Tipo OCI | Notas |
|---|---|---|
| `ignition_bucket` | `oci_objectstorage_bucket` | bucket privado temporário |
| `bootstrap_ignition` | `oci_objectstorage_object` | upload do `bootstrap.ign` |
| `master_ignition` | `oci_objectstorage_object` | upload do `master.ign` |
| `worker_ignition` | `oci_objectstorage_object` | upload do `worker.ign` |
| `bootstrap_psu` | `oci_objectstorage_preauthrequest` | presigned URL 24h |
| `master_psu` | `oci_objectstorage_preauthrequest` | presigned URL 24h |
| `worker_psu` | `oci_objectstorage_preauthrequest` | presigned URL 24h |
| `bootstrap` | `oci_core_instance` | RHCOS image, destruído após install |
| `master` | `oci_core_instance` × 3 | distribuídos em 3 FDs/ADs |
| `worker` | `oci_core_instance` × N | idem, conforme `worker_count` |
| `lb_api` | `oci_network_load_balancer_network_load_balancer` | NLB L4 para :6443 |
| `lb_ingress` | `oci_load_balancer_load_balancer` | LB L7 para :80 / :443 |
| `openshift_installer` | `null_resource` | roda `openshift-install create cluster` |
| `cluster_wait` | `null_resource` | roda `openshift-install wait-for install-complete` |

## install-config.yaml (template)

```yaml
apiVersion: v1
baseDomain: ${base_domain}
metadata:
  name: ${cluster_name}
platform:
  none: {}
pullSecret: '${pull_secret}'
sshKey: '${ssh_pub_key}'
fips: ${fips_enabled}
networking:
  networkType: OVNKubernetes
  clusterNetwork:
    - cidr: ${pod_cidr}
      hostPrefix: 23
  serviceNetwork:
    - ${service_cidr}
  machineNetwork:
    - cidr: ${vcn_cidr}
controlPlane:
  name: master
  replicas: 3
  hyperthreading: Enabled
compute:
  - name: worker
    replicas: ${worker_count}
    hyperthreading: Enabled
```

## RHCOS image

OCI Marketplace publica imagens RHCOS oficiais da Red Hat:
- Listagem: `oci compute image list --operating-system "Red Hat Enterprise Linux CoreOS"`.
- Alternativa: importar OVA/QCOW do mirror Red Hat (`mirror.openshift.com`)
  para Object Storage e criar custom image.

Módulo deve aceitar variável `rhcos_image_ocid` — se vazio, filtrar
marketplace.

## Outputs

```hcl
output "cluster_name"      { value = var.cluster_name }
output "api_endpoint"      { value = "https://api.${var.cluster_name}.${var.base_domain}:6443" }
output "console_url"       { value = "https://console-openshift-console.apps.${var.cluster_name}.${var.base_domain}" }
output "ingress_lb_ip"     { value = oci_load_balancer_load_balancer.lb_ingress.ip_address_details[0].ip_address }
output "kubeconfig_path"   { value = "${path.module}/installer-files/auth/kubeconfig" }
output "kubeadmin_password" { value = file("${path.module}/installer-files/auth/kubeadmin-password"), sensitive = true }
output "oidc_issuer_url"   { value = "https://api.${var.cluster_name}.${var.base_domain}:6443" }  # pós-extração
```

## MachineSets (pós-install)

Terraform não gerencia MachineSets (responsabilidade do Machine API
Operator). Em vez disso, fornece um `null_resource` `post_install_configs`
que aplica via `oc apply` os MachineSets custom:

- `gateway-basa-{env}-worker-a/b/c` — um por AD.
- `ClusterAutoscaler` CR com `minReplicas: 2, maxReplicas: 10` (dev).

Alternativa limpa: delegar ao Helm/Kustomize em Fase 03. Decisão registrada
em `environments.md`.

## FIPS

Se `var.fips_enabled = true`:
- `install-config.yaml` tem `fips: true`.
- RHCOS boota em FIPS mode.
- **Irreversível** — para desligar, reinstalar cluster.
- Ver `../01-docker-ubi/fips-readiness.md`.

## Decisões de design

1. **UPI vs IPI** — UPI dá controle sobre recursos OCI (tags, NSG específicos);
   IPI não existe para OCI oficialmente.
2. **NLB para API vs LB L7** — OCP API é L4 (HTTPS passthrough); Ingress
   Router aceita L7.
3. **Worker inicial mínimo** — 2 em dev, 3 em staging/prod. MAO cuida do
   scale-out.
4. **Boot volume KMS** — todos os instances com boot volume encriptado
   pelo Vault key (module-vault).
5. **Masters sempre 3** — HA mandatório em OCP; não configurável para
   economizar (contrário ao GKE zonal dev).

## Custos estimados (dev)

- 3 masters `VM.Standard.E4.Flex` 4 OCPU / 16GB = ~$210/mês.
- 2 workers `VM.Standard.E4.Flex` 2 OCPU / 8GB = ~$70/mês.
- 2 LBs = ~$20/mês.
- Storage (boot volumes 100GB × 5) = ~$15/mês.
- **Total dev: ~$315/mês** (contra ~$15/mês do GCP dev — OCP é
  substancialmente mais caro por ser self-managed).

## Controles ISO 27001

- A.8.2 — Privileged access (acesso API só via bastion + allowlist).
- A.8.14 — Redundancy (3 masters, workers multi-AD).
- A.8.24 — Use of cryptography (FIPS + KMS para boot).
- A.8.31 — Separation of environments.

## Checklist pronto-para-código

- [ ] `modules/openshift/` com orquestração UPI completa.
- [ ] Ignition configs geradas via Installer, subidas para Object Storage.
- [ ] Presigned URLs 24h (rotação automática em re-apply).
- [ ] Bootstrap node destruído após `openshift-install wait-for install-complete`.
- [ ] Kubeconfig persistido em local seguro (Secret? Vault? ver decisão).
- [ ] MachineSets pós-install aplicados (Helm ou oc-apply).
- [ ] `terraform destroy` remove cluster limpo (sem recursos órfãos).
