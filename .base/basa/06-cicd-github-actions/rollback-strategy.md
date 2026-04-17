# Rollback Strategy

## Objetivo

Definir os caminhos de rollback (automático e manual) para o Gateway no
track Basa, suas triggers, retention de revisões Helm e critérios para
escalonamento.

## Tipos de rollback

### 1. Automático (dentro do workflow)

Disparado quando `helm upgrade --atomic` detecta falha de `--wait`:
- Pod não vira `Ready` em `--timeout`.
- PostSync hook falha.
- Smoke test pós-deploy reporta erro acima do threshold.

Ação:
```
helm rollback <release> -n <namespace> 0
kubectl rollout status deploy/gateway --timeout=5m
```

`0` = revisão anterior bem-sucedida.

### 2. Manual (via runbook)

Disparado quando:
- Degradação identificada **após** deploy considerado OK (ex: erro só
  aparece após cache aquecer, ou após 30 min).
- Feature toggle / feature flag precisa ser desativada rápido.
- Incidente reportado por cliente.

Ação:
```
helm history gateway -n gateway-prod
helm rollback gateway <revision-num> -n gateway-prod
```

Detalhe completo no runbook em [`../08-runbooks/rollback.md`](../08-runbooks/rollback.md).

## Retention de revisões Helm

Helm mantém histórico em Secrets K8s (`sh.helm.release.v1.gateway.*`):

```
helm upgrade --history-max 20 ...
```

- **Dev:** 5 revisões.
- **Staging:** 10.
- **Prod:** 20 — cobre ~2 semanas de releases diárias.

Secrets rotacionam; não ocupam espaço significativo.

## Triggers de rollback automático (thresholds)

| Sinal | Threshold | Ação |
|---|---|---|
| Pod não `Ready` em `--timeout` | 10 min (prod) | `helm rollback 0` |
| `/__health` retorna ≠200 | >2 falhas em 30 requests | `helm rollback 0` |
| `liveness` probe fail em >50% dos pods | 1 min | Kubernetes reinicia; rollback se persistir |
| 5xx rate >10% (Prometheus alert `GatewayHighErrorRate`) | 5 min | **manual** (alert ao on-call) |
| Latency p99 >3× baseline | 10 min | **manual** |

Automático só cobre casos do deploy-time. Degradação pós-deploy exige
on-call.

## Rollback de Terraform

Cenário: `terraform apply` produziu regressão (ex: NSG mudou e bloqueou
tráfego). Ação:

1. **Revert commit** no repo.
2. `terraform plan` no revert mostra diff.
3. `terraform apply`.

**Nunca** fazer `terraform state rm` ou rollback manual de state em prod.

Casos destrutivos (ex: `terraform destroy` acidental):
- Recuperar `terraform.tfstate` de versão anterior no bucket OCI (Fase 02).
- Runbook em Fase 08 — `08-runbooks/disaster-recovery.md`.

## Rollback de imagem + Helm combinado

Cenário: Helm rollback reverte para revision N-1, mas a imagem usada
naquela revision não está mais no OCIR (purged por retention).

Mitigação:
- **Retention agressiva em prod** — manter `v*.*.*` imutáveis para sempre
  (Fase 02).
- **Tag de release** garantida por 180 dias em staging.
- **Dev: aceitamos perda** (imagens são triviais de rebuild).

## Rollback em múltiplos envs (cascade)

Se bug chegou a staging + prod quase simultaneamente:

1. **Prod primeiro** (reduz impacto).
2. Staging depois.
3. Dev mantém tag buggy para reprodução (debugging).

## Incident response integration

Rollback é **parte do IRP** (`.base/docs/operations/incident-response-plan.md`
+ delta em Fase 07/08):

- Rollback executado = evento de segurança low-severity (A.5.24).
- Se cause do rollback foi security issue → escala para Security Lead.
- RCA obrigatório em 48h (A.8.32).

## Comunicação

Todo rollback:
1. Slack automático (`#gateway-releases`).
2. Ticket auto-criado em Linear/Jira com commit que foi revertido.
3. Release na GitHub marcada como `draft` ou `prerelease` se era prod.

## Permissions / who can rollback

- **CI automático:** service account do pipeline (já tem permissions para helm upgrade).
- **Manual:** membros de `gateway-platform-admins` (OCP RBAC + OCI group).
- **Break-glass:** Security Lead pode forçar rollback via bastion (auditoria extensa).

## Testes de rollback

Fire drill **trimestral** em staging:
1. Deploy intencionalmente broken (`image.tag=broken`).
2. Validar rollback auto dispara.
3. Medir tempo (target < 5 min).
4. Registrar evidência em management review.

## Decisões de design

1. **Helm atomic em staging+prod** — automático em falha de deploy.
2. **Rollback manual para degradação pós-deploy** — humano decide.
3. **Retention Helm prod = 20** revisões.
4. **Tags prod imutáveis para sempre** — evita "rollback impossível".
5. **Drill trimestral** — A.8.6 (capacity & drills).

## Controles ISO 27001

- A.5.24 — Information security incident management planning.
- A.5.26 — Response to incidents.
- A.5.30 — ICT readiness for business continuity.
- A.8.32 — Change management.
- A.8.14 — Redundancy of information processing facilities.

## Checklist pronto-para-código

- [ ] Helm history-max ajustado por env.
- [ ] Rollback auto testado em staging (fire drill).
- [ ] Runbook manual (Fase 08) referencia este doc.
- [ ] Slack #gateway-releases recebe notificações.
- [ ] Auto-ticket configurado (Linear API ou GitHub Issues).
- [ ] Permissions doc de quem pode rollback.
