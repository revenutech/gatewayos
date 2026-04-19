# ADR-001 — OpenShift on OCI vs OKE + operators Red Hat

- **Status:** Aceito
- **Data:** 2026-04-17
- **Decisores:** Platform Owner, SRE Lead, Security Lead
- **Relacionado:** ADR-003, stack-reference.md §2

## Contexto

O track Basa exige um Kubernetes compatível com o ecossistema Red Hat
(Operadores RH, SCC, OpenShift Routes, Monitoring stack, ACS opcional). Duas
opções viáveis na OCI:

1. **OpenShift on OCI (self-managed)** — instalação oficial do OpenShift
   Container Platform sobre OCI via OpenShift Installer (`openshift-install`).
   Red Hat suporta oficialmente o deploy; OCI é uma das plataformas IPI/UPI.
2. **OKE (Oracle Kubernetes Engine) + operators Red Hat** — OKE gerenciado
   pela Oracle, e Red Hat Operators aplicados por cima (Prometheus Operator,
   OTel Operator, etc.). **Não** é OpenShift.

## Opções consideradas

| Critério | OpenShift on OCI | OKE + operators |
|---|---|---|
| Gerenciamento control plane | Self-managed (upgrade manual/operador) | Totalmente gerenciado por Oracle |
| Suporte Red Hat | ✅ Oficial | ❌ RH não suporta o cluster |
| Route / SCC nativos | ✅ | ❌ precisa ingresso + PSA custom |
| OpenShift Monitoring / Logging | ✅ incluso | ❌ instalar manualmente |
| ACS integrado | ✅ | 🟡 operator instala mas sem pairing nativo |
| Custo licenciamento OCP | 💰 subscription por vCPU | Zero licença Red Hat |
| Custo compute | OCI IaaS | OCI IaaS |
| Curva operacional | Alta (upgrade OCP) | Baixa (Oracle upgrade) |
| Paridade com Red Hat stack | 🟢 Total | 🟡 Parcial — "Red Hat on Kubernetes", não "OpenShift" |
| FIPS mode | ✅ via RHCOS | ❌ depende do node OS |
| OCI GPU / storage | ✅ | ✅ |

## Decisão

**Adotar OpenShift on OCI (self-managed)** como orquestrador do track Basa.

## Justificativa

1. **Objetivo explícito do track** é stack Red Hat. OKE+operators entrega
   parte, mas descaracteriza a proposta (não é OpenShift, não é auditável
   contra CIS OpenShift benchmark).
2. **Paridade com Red Hat stack** — Route, SCC, Monitoring, Logging, ACS,
   service-ca, RHCOS FIPS — só existem em OCP.
3. **Compliance** — ISO 27001 evidence mapping (Fase 07) aproveita
   diretamente o OpenShift Compliance Operator + Red Hat SCAP profiles.
4. **Lock-in aceitável** — decisão estratégica já feita (replicar stack
   Red Hat), não é dilema técnico aberto.

## Consequências

### Positivas
- Paridade total com stack Red Hat, incluindo ACS, Compliance Operator, OTel Operator.
- Evidências ISO 27001 mais diretas (Compliance Operator gera relatórios).
- FIPS nativo via RHCOS.

### Negativas
- Custo de licença OCP (subscription Red Hat).
- Upgrades são responsabilidade do time (runbook em Fase 08).
- Instalação IPI na OCI tem menos docs que AWS/Azure; primeiro bootstrap
  exige atenção (runbook dedicado em 08).
- Maior superfície operacional que Kubernetes totalmente gerenciado.

## Alternativa adiada

**OpenShift Dedicated / ROSA-like na OCI** — Red Hat não oferece managed
OpenShift na OCI na data da ADR. Reavaliar quando/se Red Hat + Oracle
anunciarem parceria managed.

## Notas de implementação (entram nas Fases 02–03)

- Usar **OpenShift Installer (IPI)** — `openshift-install create cluster`
  com `platform: none` e infra OCI criada via Terraform prévio.
- Cluster em **modo privado** (control plane e workers em subnets privadas,
  API via Bastion OCI + IP allowlist).
- **Machine Config Operator** gerencia RHCOS — não tocar nodes manualmente.
- **install-config.yaml** versionado em `.base/basa/02-iac-terraform-oci/`
  (após Fase 02 ser executada, vira `deployment/infra/oci/openshift/install-config.yaml`).
- **Cluster Autoscaler** via `ClusterAutoscaler` CR + `MachineAutoscaler` por
  MachineSet.
- Versão-alvo inicial: **OCP 4.16** (stable channel no momento da ADR).

## Revisão

Revisar esta ADR se:
- Red Hat lançar managed OpenShift na OCI (→ avaliar migração).
- OCI custar descontinuar suporte a OCP (→ avaliar OKE+operators como fallback).
- Time não tiver bandwidth para operar OCP (→ reconsiderar).
