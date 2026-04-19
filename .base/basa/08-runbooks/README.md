# Fase 08 — Runbooks

**Arquiteto Principal:** Gustavo Armoa

Runbooks operacionais do track Basa: procedures repetíveis para
bootstrap, TLS, rollback, DR e incidentes. Cada runbook é auto-contido,
testável e referenciado por outras fases.

## Arquivos

| Documento | Quando usar |
|---|---|
| [bootstrap-first-apply.md](bootstrap-first-apply.md) | Primeiro apply de infra em env novo (one-time per env) |
| [tls-on-openshift.md](tls-on-openshift.md) | Emissão, renovação e troubleshooting de certificados no Route |
| [rollback.md](rollback.md) | Rollback manual (quando auto não basta); helm history, revisão N-1 |
| [dr-failover-cross-region.md](dr-failover-cross-region.md) | Failover cross-region OCI quando `sa-saopaulo-1` indisponível |
| [incident-response-oci.md](incident-response-oci.md) | Resposta a incidente — detecção, triage, contenção, evidência, RCA |

## Princípios

1. **Testáveis** — cada runbook tem seção de **drill / exercise** para
   validar via simulação.
2. **Ownership claro** — cada runbook tem owner e backup.
3. **Pre-checks obrigatórios** — antes de executar, runbook lista
   pré-requisitos (who, what, when).
4. **Saída com evidência** — runbook gera artefatos para compliance
   (A.5.28).
5. **Versionado** — mudanças no runbook viram PR; review Security Lead
   + SRE Lead.

## Formato padrão

Cada runbook segue o esqueleto:

```markdown
# {Nome do runbook}

## Objetivo
## Owner / Backup
## Trigger — quando executar
## Pre-checks
## Procedimento
  - Passo 1
  - Passo 2
  ...
## Pós-check / validação
## Evidência a gerar
## Escalação
## Drill / exercise (cadência)
## Relacionado (links para outras fases / runbooks)
## Changelog
```

## Cadência de drill

| Runbook | Frequência | Responsável |
|---|---|---|
| bootstrap-first-apply | quando criar env novo | SRE Lead |
| tls-on-openshift | trimestral | SRE Lead |
| rollback | trimestral (uat) | DevEx |
| dr-failover-cross-region | semestral (mesa) / anual (real) | SRE Lead + Platform Owner |
| incident-response-oci | trimestral (tabletop) | Security Lead |

## Repositório paralelo de evidências

Runbooks executados registram em:

```
/compliance/evidences/runbooks/
├── {yyyy-mm-dd}-{runbook-name}-{env}.md
└── ...
```

Entries assinadas com git commit pelo executor.

## Integração com ISMS

- **A.5.24..A.5.30** — Incident management + BC — cobertos por
  `incident-response-oci.md` + `dr-failover-cross-region.md`.
- **A.5.37** — Documented operating procedures — **esta fase é A.5.37
  executado**.
- **A.8.13** — Backup — `dr-failover-cross-region.md` cobre.
- **A.8.32** — Change management — `rollback.md` cobre.

## Checklist de fechamento da Fase 08

- [ ] 6 runbooks redigidos, cada um auto-contido.
- [ ] Owner + backup atribuídos.
- [ ] Pre-checks verificáveis em comando.
- [ ] Drill cadence definida e aceita por leads.
- [ ] Estrutura de `/compliance/evidences/runbooks/` documentada.
- [ ] Cross-links com Fases 02–07 validados.

## Controles ISO 27001

- A.5.24 — Information security incident management planning.
- A.5.26 — Response to incidents.
- A.5.30 — ICT readiness for BC.
- A.5.37 — Documented operating procedures.
- A.8.13 — Backup.
- A.8.32 — Change management.

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
