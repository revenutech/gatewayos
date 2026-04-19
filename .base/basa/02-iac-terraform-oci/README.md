# Fase 02 — IaC Terraform OCI

**Arquiteto Principal:** Gustavo Armoa

Especificação dos módulos Terraform que provisionam a infraestrutura do
track Basa em Oracle Cloud Infrastructure: rede, OpenShift, registry,
secrets/KMS, DNS, monitoramento e bastion. Inclui organização de
ambientes, backend de estado e convenções de variáveis.

## Arquivos

### Módulos

| Documento | Recurso alvo |
|---|---|
| [module-vcn.md](module-vcn.md) | VCN + subnets + NSG + NAT/IGW + route tables |
| [module-openshift.md](module-openshift.md) | Cluster OpenShift on OCI (IPI) + MachineSets |
| [module-ocir.md](module-ocir.md) | OCI Container Registry + retention + IAM |
| [module-vault.md](module-vault.md) | OCI Vault + Master Encryption Keys + Secrets |
| [module-dns.md](module-dns.md) | OCI DNS zonas + records + delegação |
| [module-monitoring.md](module-monitoring.md) | OCI Monitoring + Logging + alarms |
| [module-bastion.md](module-bastion.md) | OCI Bastion service para acesso controlado |

### Orquestração

| Documento | Finalidade |
|---|---|
| [environments.md](environments.md) | Como sqa/uat/pro compõem módulos, dimensionamento e custos |
| [backend-state.md](backend-state.md) | Backend Terraform em OCI Object Storage + locking |
| [variables-tags.md](variables-tags.md) | Inputs padronizados, defined tags, freeform tags |

## Estrutura de diretório alvo (quando executar)

```
deployment/infra/oci/
├── environments/
│   ├── sqa/main.tf
│   ├── uat/main.tf
│   └── pro/main.tf
├── modules/
│   ├── vcn/
│   ├── openshift/
│   ├── ocir/
│   ├── vault/
│   ├── dns/
│   ├── monitoring/
│   └── bastion/
└── shared/
    ├── backend.tf        # partial config, preenchido por env
    ├── providers.tf      # oci + null + random + time
    └── variables.tf      # var root (tenancy_ocid, region, etc.)
```

## Princípios

1. **Um módulo por domínio** — módulos pequenos, composição em `environments/`.
2. **Tudo tageado** com `revenu-platform.*` defined tags (ver variables-tags.md).
3. **Zero recurso fora de compartment** — cada env em seu compartment OCI
   próprio (A.8.31 — Separation of environments).
4. **Estado remoto** sempre (Object Storage), `prevent_destroy` em recursos
   críticos (Vault keys, OCIR repos imutáveis de pro).
5. **Provider pinado** — versões fixas em `shared/providers.tf`.

## Ordem de apply (dependências)

```
1. vault                (KMS keys) — apply primeiro, outros referenciam
2. vcn                  (rede)
3. ocir                 (repository) — independente, pode ir em paralelo
4. dns                  (zonas)      — independente
5. openshift            (depende de vcn + vault)
6. bastion              (depende de vcn)
7. monitoring           (depende de openshift)
```

## Checklist de fechamento da Fase 02

- [ ] Todos os 7 módulos especificados com inputs/outputs/resources.
- [ ] `environments/sqa/main.tf` pseudo-código completo.
- [ ] Backend state documentado com locking.
- [ ] Defined tags e namespaces `revenu-platform.*` listadas.
- [ ] ADRs 001–003 referenciados nas decisões.
- [ ] Custos estimados por env registrados em `environments.md`.
- [ ] Prontidão para Fase 03 — outputs exportados (cluster API, OCIR URL,
      kubeconfig path, Vault OCID).

## Controles ISO 27001 tocados

- A.5.23 — Information security for use of cloud services.
- A.8.2 — Privileged access rights (IAM policies restritas).
- A.8.9 — Configuration management.
- A.8.14 — Redundancy of information processing facilities (regional options).
- A.8.20 — Networks security.
- A.8.22 — Segregation of networks.
- A.8.24 — Use of cryptography (Vault + KMS keys).
- A.8.31 — Separation of development, test and production environments.

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
