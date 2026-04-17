# Red Hat ACS (StackRox) — Plano opcional v2

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
3. Adoção de ACS no track GCP → paridade.
4. Ingresso de módulos stateful no Basa (LedgerOS, Paymentos).

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

### Secured Cluster (por cluster OCP — dev / staging / prod)

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
2. **Fase B — Enforce em dev**. Policies em block. Tune por 14 dias.
3. **Fase C — Enforce em staging**.
4. **Fase D — Enforce em prod**. Escolher janela com on-call reforçado.

## Integrações

- **Slack** — alerts críticos.
- **ServiceNow / Jira** — auto-ticket para policy violations.
- **Grafana Operator** — ACS metrics via Prometheus endpoint.
- **OCI Vault** — secrets do ACS (admin password, Postgres pass).

## Custo estimado

- Subscription Red Hat ACS: **~$200/node/mês** (verificar SKU atual).
- Compute Central (Postgres): ~$80/mês.
- Compute Sensor/Collector: overhead ~5% por node.
- **Total prod (3 workers):** ~$700/mês apenas licença.

## Alternativas se ACS não for aprovado

1. **Falco** (CNCF) — runtime detection open-source. Integra com Slack/OTel.
2. **Tetragon** (Cilium) — eBPF-based, roadmap OpenShift.
3. **Sysdig Secure** (paid) — concorrente direto de ACS.

## Decisões de design

1. **Roll-out gradual** — evita bloquear prod sem tune.
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
- [ ] Central deployado em cluster dedicado (ou prod — trade-off).
- [ ] SecuredCluster em dev/staging/prod.
- [ ] Policies iniciais importadas e tunadas.
- [ ] Slack / ticket integration ativa.
- [ ] Runbook de break-glass em Fase 08.
