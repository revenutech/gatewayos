# Fase 00 — Foundation

Fundação do track Basa: define escopo, mapeamento GCP↔OCI/OpenShift/RH,
decisões arquiteturais (ADRs) e convenções de nomenclatura. Nenhuma fase
posterior deve introduzir premissas novas sem registrar aqui.

## Arquivos

| Documento | Finalidade |
|---|---|
| [scope.md](scope.md) | Objetivo, escopo in/out, premissas, stakeholders, riscos macro |
| [equivalence-matrix.md](equivalence-matrix.md) | Tabela completa GCP ↔ OCI/OpenShift/RH (camada a camada) |
| [naming-conventions.md](naming-conventions.md) | Naming de recursos, tags, labels, namespaces |
| [adr-001-openshift-vs-oke.md](adr-001-openshift-vs-oke.md) | Escolha: OpenShift on OCI vs OKE + operators RH |
| [adr-002-registry-ocir-vs-quay.md](adr-002-registry-ocir-vs-quay.md) | Escolha: OCIR vs Quay.io como registry primário |
| [adr-003-tls-certmanager-vs-service-ca.md](adr-003-tls-certmanager-vs-service-ca.md) | Estratégia TLS: cert-manager (externo) + service-ca (interno) |
| [adr-004-red-hat-acs-opcional.md](adr-004-red-hat-acs-opcional.md) | Red Hat ACS (StackRox) como opcional, não bloqueante |

## Checklist de fechamento da Fase 00

- [ ] Escopo aprovado por Platform Owner e ISO Lead.
- [ ] Matriz de equivalência revisada — sem gaps em capacidades GCP.
- [ ] ADRs 001–004 aprovados ou explicitamente adiados.
- [ ] Naming conventions validados com time de Platform.
- [ ] Referências ISO (Cl. 4.3 Escopo, 6.1 Risco) confirmadas.

## Controles ISO 27001 tocados nesta fase

- Cl. 4.3 — Determinação do escopo do ISMS (delta OCI/OpenShift).
- Cl. 6.1.2 — Avaliação de risco (riscos macro listados em `scope.md`).
- A.5.8 — Information security in project management.
- A.5.37 — Documented operating procedures (fundamento para runbooks).
