# Runbook — Incident Response (OCI/OpenShift)

## Objetivo

Responder a incidentes de segurança ou operacionais no track Basa,
conforme IRP existente (`.base/docs/operations/incident-response-plan.md`)
+ adaptações OCI/OpenShift. Cobre detecção, triage, contenção,
erradicação, recuperação, evidência e RCA.

## Owner / Backup

- **Owner:** Security Lead (security events) / SRE Lead (operational events).
- **Backup:** Platform Owner.
- **Escalação exec:** CTO / ISO Lead.

## Classificação de severity (reuse IRP)

| Sev | Definição | SLA primeira resposta |
|---|---|---|
| SEV-0 | Total outage pro ou data breach ativo | 5 min |
| SEV-1 | Serviço degradado + customer impact OU sinal de comprometimento | 15 min |
| SEV-2 | Degradação limitada, workaround disponível | 2 h |
| SEV-3 | Warning / anomalia sem impacto imediato | next business day |

## Trigger

- Alert `GatewayHighErrorRate` (crítico).
- OCI Audit/Vault event anômalo (ex: delete de key não planejado).
- Alert `AuthFailureSpike` (JWT fail >50/s).
- Comportamento anômalo visto em Grafana / Loki / Tempo.
- Customer report indicando brecha.
- Security scan flagging active exploit.

## Fluxo geral

```
Detect → Declare (severity) → Assemble (IMT) → Contain → Investigate → Recover → RCA → Close
```

## Procedimento

### 1. Detect & Declare

- Quem detectou abre ticket de incidente (Linear/Jira com prefix `INC-`).
- Classifica severity inicial.
- Slack post em `#revenu-incidents`:
  ```
  🚨 INC-{id} | SEV-{n} | Gateway | {brief}
  Lead: @{user}
  War room: huddle em #gateway-incidents
  ```
- Paging automático via Alertmanager (PagerDuty ou Slack escalation).

### 2. Assemble IMT (Incident Management Team)

- **IC** (Incident Commander) — Security ou SRE Lead.
- **Ops** — executa actions (kubectl, Terraform, OCI CLI).
- **Comms** — atualiza stakeholders, status page (externo) se aplicável.
- **Scribe** — timeline rigoroso em ticket.

### 3. Contain (conter dano ativo)

Por **tipo de incidente**:

#### A. Comprometimento da imagem / supply chain

```
# Bloquear push de nova imagem no OCIR
# (se invasor ainda tem token)
oci iam auth-token delete --user-id $USER --auth-token-id $TOKEN

# Bloquear admission policy para exigir signature atual
oc apply -f /path/to/policy-controller-enforce.yaml   # se ainda não ativa

# Se imagem maliciosa já em pro — rollback imediato
# (ver rollback.md)
```

#### B. JWKS / identity compromise

```
# Rotacionar JWT signing keys no Keycloak (fora do scope OCI)
# Invalidar cache JWKS local do Gateway:
oc rollout restart deploy/gateway -n gateway-pro
# Adicionar tokens comprometidos ao bloom filter de revocation
```

#### C. Leak de secret

```
# Rotacionar imediatamente no OCI Vault
oci vault secret rotate --secret-id <ocid>

# ESO detecta em refreshInterval (1h) ou force:
oc annotate externalsecret <name> -n <ns> \
  force-sync=$(date +%s) --overwrite
```

#### D. Outage pro

- Ver `rollback.md` se causa é release recente.
- Ver `dr-failover-cross-region.md` se região primária caiu.

#### E. DDoS / abuse

```
# Reforçar rate-limit temporariamente:
helm upgrade gateway k8s/helm/gateway -n gateway-pro \
  --reuse-values \
  --set krakend.rateLimit.perClient=10     # override

# Bloquear origem via NSG OCI (se identificável):
oci network nsg rules add --nsg-id <lb-nsg> \
  --security-rules '[{"direction":"INGRESS","protocol":"6","source":"<attacker-cidr>","source-type":"CIDR_BLOCK","is-stateless":false,"tcp-options":{"destination-port-range":{"min":443,"max":443}}}]'
```

### 4. Investigate (evidência)

**Não contaminar cena**. Antes de mitigar, coletar:

```
# Logs 2h antes + 2h depois
oc logs deploy/gateway -n gateway-pro --since=4h > /tmp/evidence/gateway-logs.txt

# Métricas Prometheus snapshot
curl -g "http://prometheus.openshift-monitoring.svc:9091/api/v1/query_range?query={...}&start=...&end=..." \
  > /tmp/evidence/metrics.json

# OCI Audit
oci audit event list \
  --compartment-id $COMPARTMENT \
  --start-time 2026-04-17T00:00Z \
  --end-time   2026-04-17T04:00Z \
  > /tmp/evidence/oci-audit.json

# Vault audit
oci vault secret list --compartment-id $COMPARTMENT > /tmp/evidence/vault-state.json

# Snapshot do cluster (manifestos principais)
for kind in deploy svc route netpol scc configmap secret; do
  oc get $kind -A -o yaml > /tmp/evidence/${kind}.yaml
done

# etcd snapshot (se suspeita de tampering)
oc debug node/$(oc get node -l node-role.kubernetes.io/master | tail -1 | awk '{print $1}') \
  -- chroot /host /usr/local/bin/cluster-backup.sh /tmp/backup

tar -czf /tmp/evidence-${INCIDENT_ID}.tar.gz /tmp/evidence/
```

**Cadeia de custódia:** Security Lead assina SHA256 do archive e
armazena em secure location (S3 WORM bucket ou compliance repo).

### 5. Recover

- Aplicar fix (rollback ou patch).
- Validar serviço de volta ao baseline (Grafana, smoke).
- Anúncio em status page / Slack #revenu-status.

### 6. RCA — 5 Whys + timeline

Template em `.base/docs/operations/rca-template.md` (criar se não existir).
Entregáveis em 48h para SEV-0/1, 7 dias para SEV-2:

- Timeline exato (segundo a segundo nos momentos críticos).
- Root cause (técnica + sistêmica).
- Detection gap (por que não detectamos antes?).
- Contention gap (por que não contivemos mais rápido?).
- Action items (com owner e prazo).

### 7. Close

- Post-mortem public (ou interno) publicado.
- Action items virams tickets com owner.
- Retro enxerga padrões.
- Se incidente envolveu security → reporte a ISO Lead → Management Review.

## Comunicação

| Audiência | Canal | Cadência |
|---|---|---|
| IMT | Slack huddle + ticket | contínuo |
| Engineering all-hands | Slack `#engineering` | a cada hora (SEV-0/1) |
| Stakeholders externos | Email / status page | SEV-0 com customer impact |
| Legal/Compliance | Direct message ISO Lead | SEV-0 com data breach |
| Regulador | Conforme LGPD / ISO | A.5.31 — depende do caso |

## Evidência a gerar (para compliance)

- Ticket de incidente completo.
- Archive `/tmp/evidence-{id}.tar.gz` em compliance repo.
- RCA assinado.
- Action item tracker.
- Timeline importado para Management Review quarterly.

Retention: **7 anos** (A.5.33).

## Escalação

- SEV-0 sem resolução em 1h → CTO + ISO Lead paging.
- Suspeita de data breach → Legal + DPO imediato.
- Incidente envolve exploração de CVE não-aplicada → Red Hat Support
  (se componente RH) ou KrakenD maintainers.

## Drill

**Trimestral tabletop:** IMT se reúne, recebe cenário, executa runbook
mentalmente, atualiza documentação. **Semestral real:** simulação em
uat (ex: pod crash loop, fake alert).

Registrar em `/compliance/evidences/runbooks/drills/{yyyy-q}-ir-drill.md`.

## Relacionado

- `.base/docs/operations/incident-response-plan.md` (IRP baseline).
- [rollback.md](rollback.md).
- [dr-failover-cross-region.md](dr-failover-cross-region.md).
- [tls-on-openshift.md](tls-on-openshift.md).
- Fase 05 — supply chain / secrets.
- Fase 07 — risk register (mapeamento incidente ↔ risco).

## Controles ISO 27001

- A.5.24 — Incident management planning.
- A.5.25 — Event assessment.
- A.5.26 — Response to incidents.
- A.5.27 — Learning from incidents.
- A.5.28 — Evidence collection.
- A.5.29 — Infosec during disruption.
- A.5.31 — Legal/regulatory compliance.
- A.8.15 — Logging.
- A.8.16 — Monitoring activities.

## Changelog

- 2026-04-17 — v1 inicial.
