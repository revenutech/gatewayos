# Module — OCIR (OCI Container Registry)

**Arquiteto Principal:** Gustavo Armoa

## Objetivo

Provisionar o repositório de imagens no OCIR para a imagem do Gateway, com
retention policies, imutabilidade de tag (pro) e integração IAM com CI e
cluster OCP.

## Recursos OCI envolvidos

| Item | Tipo OCI |
|---|---|
| Repositório | `oci_artifacts_container_repository` |
| IAM | `oci_identity_policy` com statements específicos |
| Imutabilidade | `is_immutable = true` |
| Retenção | Retention via OCIR + cleanup job (OCIR não tem lifecycle nativo — usar CI) |
| CI pull | Token OCIR via OIDC federation + `use repositories in compartment` policy |

## Inputs

```hcl
variable "compartment_id"    { type = string }
variable "environment"       { type = string }
variable "region"            { type = string }
variable "repository_name"   { type = string }                    # gateway-basa-{env}
variable "is_immutable"      { type = bool, default = false }     # true em pro
variable "is_public"         { type = bool, default = false }
variable "keep_count"        { type = number, default = 10 }      # usado por job de cleanup
variable "ci_dynamic_group_id" { type = string }                  # dynamic group do CI (OIDC)
variable "ocp_dynamic_group_id" { type = string }                 # nodes OCP (instance principal)
variable "defined_tags"      { type = map(string) }
```

## Recursos

| Nome TF | Tipo OCI | Notas |
|---|---|---|
| `repo` | `oci_artifacts_container_repository` | `gateway-basa-{env}/gateway` |
| `policy_ci_push` | `oci_identity_policy` | CI: push/tag/inspect |
| `policy_ocp_pull` | `oci_identity_policy` | OCP nodes: pull apenas |
| `scan_config` | `oci_artifacts_container_image_scanning_config` | Scan nativo OCIR (opcional) |

## Retention

OCIR **não tem lifecycle policy nativo**. Duas estratégias:

1. **Job de CI** — workflow `retention-oci.yml` rodando semanalmente:
   - Lista tags via `oci artifacts container image list`.
   - Mantém: últimas N tags + todas `v*.*.*`.
   - Deleta o resto via `oci artifacts container image delete`.
2. **Manual** — runbook em Fase 08 para cleanup trimestral.

V1 adota opção 1. Script entra em `06-cicd-github-actions/`.

## Imutabilidade

- **sqa:** `is_immutable = false` (sobrescrever `sqa-latest` permitido).
- **uat:** `is_immutable = false` mas com proteção contra deletar
  tags `v*.*.*-rc*`.
- **pro:** `is_immutable = true` — uma vez pushado, tag é eterna.

## Imagem scanning

OCIR oferece vulnerability scanning nativo (powered by Oracle Linux
Vulnerability Assessment). **Usar como camada extra**; não substitui Trivy.

Habilitar via `oci_artifacts_container_image_scanning_config` com
`scanning_enabled = true`.

Relatórios visíveis em OCI Console; Fase 05 documenta como ingerir via
Monitoring/alerting.

## IAM policies

### CI (push)

```hcl
# policy_ci_push
statements = [
  "Allow dynamic-group ${var.ci_dynamic_group_id} to manage repos in compartment id ${var.compartment_id} where target.repo.name='${var.repository_name}'",
  "Allow dynamic-group ${var.ci_dynamic_group_id} to read repos in compartment id ${var.compartment_id}"
]
```

### OCP nodes (pull)

```hcl
# policy_ocp_pull
statements = [
  "Allow dynamic-group ${var.ocp_dynamic_group_id} to read repos in compartment id ${var.compartment_id} where target.repo.name='${var.repository_name}'"
]
```

### Admin / breakglass

Apenas membros do grupo `gateway-platform-admins` (definido fora deste
módulo). Não criar keys estáticas.

## Outputs

```hcl
output "repo_ocid"        { value = oci_artifacts_container_repository.repo.id }
output "repo_url"         { value = "${data.oci_objectstorage_namespace.ns.namespace}.${var.region}.ocir.io/${data.oci_objectstorage_namespace.ns.namespace}/${var.repository_name}" }
output "repo_name_full"   { value = "${var.repository_name}/gateway" }
```

> URL OCIR: `{region-key}.ocir.io/{tenancy-namespace}/{repo}:{tag}`.
> Ex: `gru.ocir.io/revenutech/gateway-basa-sqa/gateway:v1.0.0`.

## Decisões de design

1. **Um repo por env** (não múltiplos repos por env compartilhando namespace)
   — simplifica IAM e retention.
2. **Scanning OCIR ativo** em todos os envs (gratuito para repos privados).
3. **Dynamic groups** — CI e OCP nodes acessam via instance/resource
   principal, nunca via keys.
4. **Region = mesma do cluster OCP** — evita egress inter-region.
5. **Sem replication cross-region na v1** — DR runbook trata recuperação
   manual (Fase 08).

## Controles ISO 27001

- A.8.9 — Configuration management (imagens imutáveis em pro).
- A.8.8 — Vulnerability management (scanning).
- A.8.4 — Access to source code / artifacts (IAM policies).

## Checklist pronto-para-código

- [ ] `modules/ocir/main.tf` + `variables.tf` + `outputs.tf`.
- [ ] Retention job documentado em Fase 06.
- [ ] CI consegue `docker push` via OIDC federation sem keys estáticas.
- [ ] OCP pull secret gerado automaticamente (External Secrets Operator
      lê de Vault).
- [ ] Imagem `v0.0.1-smoke` pushada com sucesso para sqa em smoke test
      pós-apply.

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
