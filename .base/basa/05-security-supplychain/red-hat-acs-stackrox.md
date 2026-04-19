# Red Hat ACS (StackRox) — Plano opcional v2

**Arquiteto Principal:** Gustavo Armoa

## Status — v1: NÃO ADOTAR

Decisão consolidada em [ADR-004](../00-foundation/adr-004-red-hat-acs-opcional.md):
track Basa v1 **não adota ACS**. Controles equivalentes cobertos por:

- Trivy (build + admission cluster-side opcional).
- NetworkPolicy exhaustiva + AdminNetworkPolicy.
- Compliance Operator (CIS OCP benchmark).
- Sigstore policy-controller (admission de assinatura).

Este documento descreve o plano de adoção **futura** (v2), para quando
um dos gatilhos do ADR-004 ocorrer.

## Gatilhos que ativam o plano

1. Incidente em que runtime detection teria evitado dano.
2. Requisito regulatório novo (SOC 2 Type II, FedRAMP, PCI DSS runtime).
3. Ingresso de módulos stateful no Basa (LedgerOS, Paymentos).

## O que ACS entrega

| Capacidade | Já coberto? | Gain com ACS |
|---|---|---|
| Vuln management | Trivy ✅ | Clair + correlation + BOM view |
| Admission controller | Sigstore ✅ (parcial) | Policies ricas (privileged, caps, volumes) |
| Runtime detection (proc/net) | ❌ | **Único em ACS** |
| Compliance profiles (CIS/NIST) | Compliance Operator ✅ | Multi-cluster aggregated view |
| Network graph + segmentation simulator | ❌ | Recomenda NetPol faltantes |
| Image scanning integrado a Admission | parcial | Block por CVE antes do pod rodar |

**Gain real:** runtime detection + network graph.

## Arquitetura ACS

```
┌──────────────────────────────────────┐
│ Central (UI + API)                   │
│ Postgres backend                     │
│ Namespace: stackrox-central          │
└──────────────┬───────────────────────┘
               │ gRPC mTLS
┌──────────────▼───────────────────────┐
│ Secured Cluster (per cluster OCP)    │
│ - Sensor (DaemonSet)                 │
│ - Collector (eBPF)                   │
│ - Admission Controller               │
│ Namespace: stackrox                  │
└──────────────────────────────────────┘
```

## Instalação (quando aprovado)

### Central

```yaml
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: rhacs-operator
  namespace: stackrox-operator
spec:
  channel: stable
  name: rhacs-operator
  source: redhat-operators
---
apiVersion: platform.stackrox.io/v1alpha1
kind: Central
metadata:
  name: stackrox-central
  namespace: stackrox-central
spec:
  central:
    exposure:
      route:
        enabled: true
    persistence:
      persistentVolumeClaim:
        storageClassName: oci-bv
        size: 100Gi
  scanner:
    analyzer:
      scaling:
        autoScaling: Enabled
        minReplicas: 2
        maxReplicas: 5
```

### Secured Cluster (por cluster OCP — sqa / uat / pro)

```yaml
apiVersion: platform.stackrox.io/v1alpha1
kind: SecuredCluster
metadata:
  name: stackrox-secured
  namespace: stackrox
spec:
  clusterName: gateway-basa-{env}-ocp
  centralEndpoint: central-stackrox-central.apps.{central-cluster}:443
  admissionControl:
    listenOnCreates: true
    listenOnUpdates: true
    listenOnEvents: true
    contactImageScanners: ScanIfMissing
    bypass: BreakGlassAnnotation
    timeoutSeconds: 20
  perNode:
    collector:
      collection: CORE_BPF         # eBPF — sem kmod
      imageFlavor: Regular
```

## Policies iniciais

### Build/Deploy policies

- **No Signed Image** — block deploy sem Cosign signature.
- **High-severity CVE unfixable** — block (ignore-unfixed compatível).
- **No Privileged Container** — block.
- **No Run as Root** — warn (com PSA já cobre).
- **Required Label `app.kubernetes.io/part-of`** — warn.
- **Image from unauthorized registry** — block (só `gru.ocir.io/revenutech/*`).

### Runtime policies

- **Shell spawned in container** — alert (Gateway não abre shell).
- **Writable Root FS** — alert (Fase 03 força readOnly).
- **Unauthorized Network Connection** — alert (NetPol já bloqueia; ACS detecta tentativas).
- **Process outside binary baseline** — alert (KrakenD é o único PID 1 esperado).

## Rollout strategy

1. **Fase A — Install em modo observe**. ACS observa, não bloqueia.
   Duração: 30 dias.
2. **Fase B — Enforce em sqa**. Policies em block. Tune por 14 dias.
3. **Fase C — Enforce em uat**.
4. **Fase D — Enforce em pro**. Escolher janela com on-call reforçado.

## Integrações

- **Slack** — alerts críticos.
- **ServiceNow / Jira** — auto-ticket para policy violations.
- **Grafana Operator** — ACS metrics via Prometheus endpoint.
- **OCI Vault** — secrets do ACS (admin password, Postgres pass).

## Custo estimado

- Subscription Red Hat ACS: **~$200/node/mês** (verificar SKU atual).
- Compute Central (Postgres): ~$80/mês.
- Compute Sensor/Collector: overhead ~5% por node.
- **Total pro (3 workers):** ~$700/mês apenas licença.

## Alternativas se ACS não for aprovado

1. **Falco** (CNCF) — runtime detection open-source. Integra com Slack/OTel.
2. **Tetragon** (Cilium) — eBPF-based, roadmap OpenShift.
3. **Sysdig Secure** (paid) — concorrente direto de ACS.

## Decisões de design

1. **Roll-out gradual** — evita bloquear pro sem tune.
2. **CORE_BPF** no Collector — sem kmod (mais leve, RHCOS 4.16+).
3. **Bypass via annotation** — break-glass para emergências.
4. **Policies-as-code** — `SecurityPolicy` CRs versionadas em git.
5. **Grafana dashboards** — manter visão unificada com outras métricas.

## Controles ISO 27001 adicionais cobertos por ACS

- A.8.7 — Protection against malware (runtime detection).
- A.8.16 — Monitoring activities (runtime).
- A.8.22 — Segregation of networks (network graph).
- A.8.28 — Secure coding (deploy policies).

## Checklist para futuro rollout

- [ ] Subscription Red Hat ACS aprovada.
- [ ] ADR-004 atualizado para "Aceito — em adoção".
- [ ] Central deployado em cluster dedicado (ou pro — trade-off).
- [ ] SecuredCluster em sqa/uat/pro.
- [ ] Policies iniciais importadas e tunadas.
- [ ] Slack / ticket integration ativa.
- [ ] Runbook de break-glass em Fase 08.

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
