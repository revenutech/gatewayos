# Fase 07 — ISO 27001 (Delta OCI/OpenShift)

Capítulo OCI/OpenShift do ISMS do Gateway. Complementa `.base/docs/`
(ISMS baseline) com os artefatos específicos do track Basa (OCI +
OpenShift + Red Hat). Produz:

- **Controls Matrix** — para cada controle Annex A, evidência
  OCI/OpenShift.
- **Statement of Applicability (SoA)** — quais controles se aplicam ao
  track Basa + justificativa.
- **Risk Register** — riscos macro do Basa (B-R01..R04 de Fase 00)
  consolidados aqui, além de revisão dos R01..R18 existentes.
- **Evidence Mapping** — onde coletar evidência em OCI/OpenShift para
  auditoria.

## Arquivos

| Documento | Finalidade |
|---|---|
| [controls-matrix-delta.md](controls-matrix-delta.md) | 93 controles Annex A com evidência OCI/OpenShift |
| [soa-oci.md](soa-oci.md) | SoA com aplicabilidade no track Basa e justificativas |
| [risk-register-delta.md](risk-register-delta.md) | Riscos macro do Basa (B-R01..R04) + revisão dos R01..R18 existentes |
| [evidence-mapping.md](evidence-mapping.md) | Onde / como coletar evidência (OCI Console paths, oc commands, export formats) |

## Relação com ISMS existente

```
.base/docs/                       # ISMS baseline (cloud-agnóstico)
├── isms/                         # escopo, política, papéis, manual
├── risk/
│   ├── risk-methodology.md       # metodologia
│   ├── risk-register.md          # R01..R18 baseline
│   ├── statement-of-applicability.md  # SoA baseline
│   └── threat-model.md
├── compliance/
│   └── controls-matrix.md        # 93 controles baseline
├── operations/                   # IRP, BCP, change mgmt, runbooks
└── metrics/

.base/basa/07-iso27001/           # capítulo OCI/OpenShift
├── controls-matrix-delta.md      # evidência Basa para os 93 controles
├── soa-oci.md                    # SoA do track Basa
├── risk-register-delta.md        # riscos Basa-specific + revisão dos R01..R18
└── evidence-mapping.md           # where-to-find-evidence em OCI/OpenShift
```

**Não duplicar.** Os documentos aqui **referenciam** os principais do
ISMS e adicionam o que é OCI/OpenShift-specific.

## Atualização do ISMS principal

Após aceitar esta Fase 07, o ISMS principal deve:

1. **ISMS Scope Statement** (`.base/docs/isms/scope-statement.md`) —
   adicionar parágrafo incluindo OCI tenancy + OpenShift clusters no
   escopo.
2. **Risk Register** — adicionar apêndice apontando para
   `risk-register-delta.md` do Basa.
3. **SoA** — adicionar coluna ou apêndice referenciando `soa-oci.md`.
4. **Controls Matrix** — adicionar coluna "Evidência Basa (OCI)" ou
   linkar para este capítulo.

Essas mudanças ao ISMS principal **ficam fora** de `.base/basa/` — são
alterações definitivas no ISMS, não plano.

## Abordagem

1. **Aplicabilidade explícita** — todo controle Annex A avaliado com
   aplicabilidade no track Basa e justificativa para exclusões.
2. **Evidência nativa OCI/OpenShift** — comandos, console paths e
   artefatos concretos.
3. **Risk register** — R01..R18 baseline continuam válidos; riscos
   B-R01..R04 cobrem o que é OCI/OpenShift-specific.
4. **Auditoria pronta** — `evidence-mapping.md` dá ao auditor caminho
   direto para cada controle.

## Checklist de fechamento da Fase 07

- [ ] 93 controles Annex A com evidência Basa documentada.
- [ ] SoA com coluna "aplicável no Basa" + "justificativa" completa.
- [ ] Novos riscos B-R01..R04 avaliados com L/I/Score/Level.
- [ ] Riscos R01..R18 revisados — impacto em Basa confirmado ou
      atualizado.
- [ ] Evidence mapping lista ≥1 fonte concreta por controle.
- [ ] Plano de atualização do ISMS principal documentado.
- [ ] `compliance-oci.yml` valida presença destes docs (Fase 06).

## Controles ISO 27001 tocados por esta fase (meta)

- Cl. 4.3 — Escopo ISMS (expansão).
- Cl. 6.1.2 — Risk assessment (novos riscos).
- Cl. 6.1.3 — Risk treatment + SoA (atualização).
- Cl. 9.1 — Monitoring and measurement (evidence mapping alimenta).
- Cl. 9.2 — Internal audit (este delta facilita auditoria do Basa).
- A.5.36 — Compliance with policies.
- A.5.37 — Documented operating procedures.
