# Environments (sqa / uat / pro)

**Arquiteto Principal:** Gustavo Armoa

## Objetivo

Descrever como os módulos da Fase 02 se compõem em cada ambiente, com
dimensionamento, custos estimados e especificidades.

## Estrutura de diretório por env

```
deployment/infra/oci/environments/{env}/main.tf
```

Cada `main.tf` declara:

1. `terraform { backend "s3" { ... } }` — apontando para OCI Object Storage
   (ver `backend-state.md`).
2. `provider "oci"` — região do env.
3. `locals` — tags, naming prefix.
4. `module "vault"` — KMS keys primeiro (outros dependem).
5. `module "vcn"` — rede.
6. `module "ocir"` — registry.
7. `module "dns"` — zona DNS.
8. `module "openshift"` — cluster (depende de vcn, vault, dns).
9. `module "bastion"` — acesso administrativo.
10. `module "monitoring"` — pós-cluster.

## Dimensionamento por env

### sqa

| Item | Valor | Observação |
|---|---|---|
| Compartment | `gateway-basa-sqa` | |
| Region | `sa-saopaulo-1` | primária para todos os envs |
| VCN CIDR | `10.40.0.0/16` | |
| Masters | 3 × `VM.Standard.E4.Flex` 4 OCPU / 16 GB | mínimo OCP |
| Workers | 2 × `VM.Standard.E4.Flex` 2 OCPU / 8 GB | autoscaler 2–4 |
| Vault | SOFTWARE protection | economia |
| OCIR | mutable tags, keep=10 | |
| Bastion TTL | 3h | |
| Flow logs retention | 30 dias | |
| OCP version | 4.16.x | |
| FIPS | off | |

**Custo estimado:** ~$350/mês (OCP self-managed é caro; runbook em Fase 08
discute stop/start em horário não-útil para economia).

### uat

| Item | Valor | Observação |
|---|---|---|
| Compartment | `gateway-basa-uat` | |
| Region | `sa-saopaulo-1` | |
| VCN CIDR | `10.41.0.0/16` | |
| Masters | 3 × `VM.Standard.E4.Flex` 4 OCPU / 16 GB | |
| Workers | 3 × `VM.Standard.E4.Flex` 2 OCPU / 8 GB | autoscaler 3–6 |
| Vault | HSM | paridade pro |
| OCIR | mutable + protected RC tags | |
| Bastion TTL | 3h | |
| Flow logs retention | 60 dias | |
| OCP version | 4.16.x (mesma minor de pro) | |
| FIPS | off (pode ligar para drill) | |

**Custo estimado:** ~$450/mês.

### pro

| Item | Valor | Observação |
|---|---|---|
| Compartment | `gateway-basa-pro` | |
| Region | `sa-saopaulo-1` (primária) + DR `sa-vinhedo-1` (futuro) | |
| VCN CIDR | `10.42.0.0/16` | |
| Masters | 3 × `VM.Standard.E4.Flex` 4 OCPU / 16 GB | |
| Workers | 3 × `VM.Standard.E4.Flex` 4 OCPU / 16 GB | autoscaler 3–8 |
| Vault | HSM | obrigatório |
| OCIR | immutable tags | v*.*.* eterno |
| Bastion TTL | 1h | menor janela |
| Flow logs retention | 90 dias (+ archive 7 anos) | |
| OCP version | 4.16.x (latest stable) | |
| FIPS | off v1 (gatilho para ligar em fips-readiness.md) | |

**Custo estimado:** ~$700–900/mês dependendo de autoscaling.

## Ordem de apply

Para **bootstrap do zero** (cada env):

```
1. terraform apply -target=module.vault
2. terraform apply -target=module.vcn -target=module.ocir -target=module.dns
3. Runbook: delegação NS em allenty.io → oci.allenty.io
4. Runbook: popular secret pull_secret_rh e ocir_push em Vault
5. terraform apply -target=module.openshift
6. Runbook: aplicar MachineSets + ClusterAutoscaler CRs
7. terraform apply -target=module.bastion
8. terraform apply -target=module.monitoring
9. terraform apply (final, reconcilia tudo)
```

Para **updates rotineiros** (cluster já existente): `terraform apply`
direto; dependency graph cuida da ordem.

## Per-env overrides importantes

| Var | sqa | uat | pro |
|---|---|---|---|
| `master_shape` | E4.Flex 4/16 | E4.Flex 4/16 | E4.Flex 4/16 |
| `worker_ocpus` | 2 | 2 | 4 |
| `worker_count` initial | 2 | 3 | 3 |
| `worker_max` | 4 | 6 | 8 |
| `vault_protection` | SOFTWARE | HSM | HSM |
| `ocir_immutable` | false | false | true |
| `bastion_ttl` | 10800 | 10800 | 3600 |
| `flow_log_retention_days` | 30 | 60 | 90 |
| `fips_enabled` | false | false | false (v1) |
| `notification_email` | sqa-oncall@revenu | uat-oncall@revenu | oncall@revenu |

## Separação por compartment (A.8.31)

Cada env em seu próprio **compartment** OCI:

```
tenancy root
└── revenu-platform
    ├── gateway-basa-sqa
    ├── gateway-basa-uat
    └── gateway-basa-pro
```

Policies escritas com `in compartment id ${compartment}` — impede
vazamento cross-env por erro.

## Tags uniformes

Todos os recursos recebem:

```
revenu-platform.app        = gateway
revenu-platform.track      = basa
revenu-platform.env        = {sqa|uat|pro}
revenu-platform.managed-by = terraform
revenu-platform.iso27001   = true
revenu-platform.owner      = platform-team
revenu-platform.cost-center = platform
```

## Checklist pronto-para-código

- [ ] 3 arquivos `environments/{env}/main.tf` com composição de módulos.
- [ ] `variables.tf` por env com defaults adequados.
- [ ] Ordem de apply documentada em runbook.
- [ ] Custos estimados revisados com calculator OCI + Red Hat subscription.
- [ ] Compartments criados no tenancy (manual ou via TF nível acima).

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
