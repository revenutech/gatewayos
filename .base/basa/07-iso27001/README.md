# Fase 07 — ISO 27001 (Delta OCI/OpenShift)

**Delta** sobre o ISMS existente (`.base/docs/`) para incorporar o track
Basa (OCI + OpenShift + Red Hat) sem reescrever o ISMS. Produz:

- **Controls Matrix Delta** — para cada controle Annex A que mude, mostra
  a evidência OCI/OpenShift.
- **Statement of Applicability (SoA) OCI** — quais controles se aplicam
  ao track Basa + justificativa.
- **Risk Register Delta** — novos riscos exclusivos do Basa (B-R01..R06
  já definidos em Fase 00; consolidados aqui).
- **Evidence Mapping** — onde coletar evidência em OCI/OpenShift para
  auditoria.

## Arquivos

| Documento | Finalidade |
|---|---|
| [controls-matrix-delta.md](controls-matrix-delta.md) | 93 controles Annex A — evidência GCP (já existente) + evidência Basa |
| [soa-oci.md](soa-oci.md) | SoA estendida com aplicabilidade no track Basa e justificativas |
| [risk-register-delta.md](risk-register-delta.md) | Riscos exclusivos OCI/OpenShift (B-R01..R06) + revisão dos R01..R18 existentes |
| [evidence-mapping.md](evidence-mapping.md) | Onde / como coletar evidência (OCI Console paths, oc commands, export formats) |

## Relação com ISMS existente

```
.base/docs/                       # ISMS do Gateway (cloud-agnóstico + GCP)
├── isms/                         # escopo, política, papéis, manual
├── risk/
│   ├── risk-methodology.md       # metodologia — inalterada
│   ├── risk-register.md          # R01..R18 (GCP) — inalterada
│   ├── statement-of-applicability.md  # SoA baseline
│   └── threat-model.md
├── compliance/
│   └── controls-matrix.md        # 93 controles com evidências GCP
├── operations/                   # IRP, BCP, change mgmt, runbooks
└── metrics/

.base/basa/07-iso27001/           # DELTA para OCI/OpenShift
├── controls-matrix-delta.md      # complementa controls-matrix.md
├── soa-oci.md                    # complementa statement-of-applicability.md
├── risk-register-delta.md        # complementa risk-register.md
└── evidence-mapping.md           # novo — where-to-find-evidence
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
   linkar para este delta.

Essas mudanças ao ISMS principal **ficam fora** de `.base/basa/` — são
alterações definitivas no ISMS, não plano.

## Abordagem

1. **Paridade de aplicabilidade** — controles aplicáveis ao GCP são
   aplicáveis ao Basa (mesma superfície funcional). Exceções documentadas.
2. **Evidência nativa OCI/OpenShift** — substitui evidência GCP sem
   enfraquecer.
3. **Risk register diff-only** — se risco R01 (JWT theft) continua
   válido em Basa, não reescrever; apenas **atualizar** evidência de
   treatment para versão Basa.
4. **Novos riscos explícitos** — B-R01..R06 cobrem o que é OCI-specific.
5. **Auditoria pronta** — `evidence-mapping.md` dá ao auditor caminho
   direto para cada controle.

## Checklist de fechamento da Fase 07

- [ ] Delta dos 93 controles documentado.
- [ ] SoA com coluna "aplicável no Basa" + "justificativa" completa.
- [ ] Novos riscos B-R01..R06 avaliados com L/I/Score/Level.
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
