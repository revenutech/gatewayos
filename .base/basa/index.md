# Basa — Deploy Track OCI / OpenShift / Red Hat

> Plano documental da esteira de deploy do Gateway sobre Oracle Cloud
> Infrastructure (OCI), Red Hat OpenShift Container Platform (OCP) e imagem
> base Red Hat UBI. **Este diretório contém apenas documentação.** Nenhum
> artefato executável (Terraform, Dockerfile, Helm, workflow) vive aqui.
> Quando uma fase for executada, o código vai para seus caminhos definitivos
> no repositório (`deployment/infra/oci/`, `docker/`, `k8s/helm/gateway/`,
> `.github/workflows/`).

## Objetivo

Documentar todo o ciclo de vida do Gateway em infraestrutura Oracle,
orquestração OpenShift e imagem base Red Hat UBI, com segurança, supply
chain, observabilidade, compliance ISO 27001 e CI/CD via GitHub Actions.

## Stack

| Camada | Tecnologia |
|---|---|
| Rede | OCI VCN + subnets + NSG |
| Kubernetes | OpenShift on OCI |
| Registry | OCI Container Registry (OCIR) |
| Secrets / KMS | OCI Vault |
| DNS | OCI DNS |
| TLS | OpenShift Route + cert-manager |
| Ingress | OpenShift Route (HAProxy) |
| Observabilidade | OpenShift Monitoring + Red Hat OTel Operator |
| Logging | OpenShift Logging (Loki) + OCI Logging |
| Base image | UBI9-minimal + KrakenD CE 2.9.4 |
| IAM CI | OCI OIDC Federation |
| Estado TF | OCI Object Storage |
| Supply chain | Cosign + Trivy (ou Red Hat ACS) + SBOM CycloneDX |

## Fases

| # | Pasta | Foco | Status |
|---|---|---|---|
| 00 | [00-foundation/](00-foundation/README.md) | Escopo, ADRs, convenções, stack reference | 📝 Documentado |
| 01 | [01-docker-ubi/](01-docker-ubi/README.md) | Dockerfile UBI9 + KrakenD + RH cert | 📝 Documentado |
| 02 | [02-iac-terraform-oci/](02-iac-terraform-oci/README.md) | Módulos Terraform OCI + envs | 📝 Documentado |
| 03 | [03-kubernetes-openshift/](03-kubernetes-openshift/README.md) | Helm chart + Route + SCC + NetPol | 📝 Documentado |
| 04 | [04-observability/](04-observability/README.md) | Prometheus / Grafana / OTel / Logging | 📝 Documentado |
| 05 | [05-security-supplychain/](05-security-supplychain/README.md) | Cosign, SBOM, Trivy, ACS, FIPS | 📝 Documentado |
| 06 | [06-cicd-github-actions/](06-cicd-github-actions/README.md) | OIDC + CI + CD sqa/uat/pro | 📝 Documentado |
| 07 | [07-iso27001/](07-iso27001/README.md) | Controls matrix, SoA, risk register | 📝 Documentado |
| 08 | [08-runbooks/](08-runbooks/README.md) | Bootstrap, TLS, rollback, DR, IR | 📝 Documentado |

Legenda: `📝 Documentado` · `🛠 Em execução` · `✅ Em produção`

## Padrão de cada documento

Cada arquivo de fase segue o mesmo esqueleto:

1. **Objetivo** — o que a peça resolve no fluxo.
2. **Design / fluxo** — decisões, trade-offs, diagrama textual.
3. **Especificação** — parâmetros, nomes, flags (pronto para virar código).
4. **Referências ISO 27001** — controles Annex A tocados.
5. **Checklist de implementação** — o que precisa existir para "pronto para executar".

## Glossário

- **UBI9** — Red Hat Universal Base Image 9, gratuito, redistribuível, suportado por Red Hat.
- **SCC** — SecurityContextConstraints, análogo OpenShift ao PodSecurityPolicy/PSA.
- **OCIR** — OCI Container Registry.
- **OVN-K** — OVN-Kubernetes, CNI padrão do OpenShift 4.
- **Route** — recurso OpenShift para exposição HTTP/TLS, roda sobre HAProxy.
- **ACS / StackRox** — Red Hat Advanced Cluster Security, policy + admission control.
- **cert-manager** — operator K8s para emissão/rotação automática de certificados.
- **service-ca** — CA interna do OpenShift para certificados intra-cluster.
- **FIPS mode** — modo de criptografia validada FIPS 140-2/3, suportado por RHCOS.
- **OIDC Federation (OCI)** — autenticação federada OIDC para workloads externos (ex: GitHub Actions) sem API keys.

## Princípios

1. **Só documentação** aqui.
2. Cada doc deve ser **executável por um terceiro** — detalhe suficiente para virar PR de código.
3. **ISO como parte do plano**, não apêndice — cada fase referencia seus controles.
4. **Navegável top-down** a partir deste `index.md`.

## Como contribuir

- Alterações de escopo entram via ADR em `00-foundation/`.
- Mudança de conteúdo dentro de uma fase: editar o arquivo e atualizar o status no índice quando aplicável.
- Não duplicar conteúdo entre fases — referenciar por link relativo.
