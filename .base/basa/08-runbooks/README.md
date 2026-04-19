# Fase 08 — Runbooks

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
