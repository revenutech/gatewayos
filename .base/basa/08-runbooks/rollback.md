# Runbook — Rollback Manual

## Objetivo

Executar rollback manual do Gateway em OCP quando: (a) rollback automático
não disparou, (b) degradação apareceu pós-deploy, (c) feature toggle
obrigou reverter release.

Complementa [Fase 06 `rollback-strategy.md`](../06-cicd-github-actions/rollback-strategy.md).

## Owner / Backup

- **Owner:** DevEx (on-call).
- **Backup:** SRE Lead.
- **Aprovador (prod):** 1 reviewer de `gateway-platform-admins`.

## Trigger

- Alert `GatewayHighErrorRate` > 5 min sem auto-rollback.
- Reporte de cliente indicando degradação.
- Incidente de segurança atrelado ao release atual (ex: CVE recém-publicado).
- Feature toggle precisa ser revertida (usualmente via código + redeploy).

## Pre-checks

- [ ] Confirmar sintoma real via Grafana / Loki / Alertmanager — não é falso positivo.
- [ ] Identificar revisão estável anterior via `helm history`.
- [ ] Confirmar que imagem da revisão anterior ainda existe em OCIR
      (prod: imagens `v*.*.*` são imutáveis, sempre disponíveis).
- [ ] Abrir ticket de incidente (Linear / Jira).
- [ ] Notificar `#gateway-critical` no Slack **antes** do rollback.
- [ ] Aprovador disponível (prod).

## Procedimento

### 1. Fetch kubeconfig

```
oci secrets secret-bundle get \
  --secret-id $OCP_KUBECONFIG_SECRET_OCID_PROD \
  --query 'data."secret-bundle-content".content' --raw-output \
  | base64 -d > ~/.kube/config
chmod 600 ~/.kube/config
```

### 2. Listar revisões

```
helm history gateway -n gateway-prod --max 20
```

Saída:

```
REVISION  UPDATED       STATUS       CHART             APP VERSION  DESCRIPTION
23        Wed Apr 17 ...  deployed     gateway-0.1.0     2.9.4-v1.4.0  Upgrade complete
22        Wed Apr 17 ...  superseded   gateway-0.1.0     2.9.4-v1.3.5  Upgrade complete
21        Tue Apr 16 ...  superseded   gateway-0.1.0     2.9.4-v1.3.4  Upgrade complete
```

Identificar **última revisão estável** (ex: 22).

### 3. Rollback

```
helm rollback gateway 22 -n gateway-prod \
  --wait --timeout 5m
```

Ou para a revisão anterior imediata:

```
helm rollback gateway 0 -n gateway-prod \
  --wait --timeout 5m
```

`0` = revisão anterior automaticamente.

### 4. Verificar rollout

```
kubectl -n gateway-prod rollout status deploy/gateway --timeout=5m

oc get pods -n gateway-prod -l app.kubernetes.io/name=gateway
oc get deploy gateway -n gateway-prod -o yaml \
  | grep 'image:'
```

Verificar que a tag da imagem voltou para `v1.3.5` (ou correspondente).

### 5. Smoke

```
HOST=$(oc get route gateway -n gateway-prod -o jsonpath='{.spec.host}')
for i in $(seq 1 10); do
  curl -fsS --max-time 5 "https://${HOST}/__health" | head -1
  sleep 1
done
```

Todas 10 retornam 200.

### 6. Confirmar alertas silenciam

- Alertmanager: alertas `GatewayHighErrorRate` viram `inactive` em ≤10 min.
- Grafana dashboard: 5xx rate volta a baseline.
- Logs Loki: erros param de incrementar.

## Cenário: imagem não disponível em OCIR (emergência)

Se a imagem alvo do rollback foi purged (não deveria acontecer em prod
com immutable tags):

1. **Rebuild from git:**
   ```
   git checkout v1.3.5
   gh workflow run cd-production-oci.yml --ref v1.3.5 \
     -f image_tag=v1.3.5-rebuild -f change_ticket=ROLLBACK-EMERG
   ```
2. Aguardar build + push (~10 min).
3. `helm rollback` com `--set image.tag=v1.3.5-rebuild`.

Esse é pior caso — documentar RCA para garantir retention policy correta.

## Pós-rollback

- [ ] Notificar Slack que rollback completou (`✅ Rollback to v1.3.5 DONE`).
- [ ] Atualizar ticket de incidente com timeline.
- [ ] Marcar release revertido como `draft` no GitHub.
- [ ] Iniciar RCA em 48h.
- [ ] Identificar bug, abrir PR de fix.
- [ ] Fix em dev → staging → re-deploy prod.

## Evidência a gerar

- `helm history` antes + depois em
  `/compliance/evidences/runbooks/{yyyy-mm-dd}-rollback-{env}.md`.
- Timeline com timestamp + action + actor.
- Screenshot Grafana do período (5xx curve).
- Ticket link.

## Escalação

- Rollback `helm rollback` falha (`error: release gateway failed`):
  → Platform Owner, considerar `helm uninstall` + `helm install` como
  último recurso **somente em dev**.
- Prod em degradação severa e rollback não resolve → invocar
  [incident-response-oci.md](incident-response-oci.md).
- Múltiplos rollbacks em <24h → freeze de releases + post-mortem
  mandatório.

## Drill

**Trimestral em staging:**
1. Deploy intencional com `image.tag=<known-broken-image>`.
2. Validar rollback manual dispara em <5 min.
3. Registrar tempo + passos em
   `/compliance/evidences/runbooks/drills/{yyyy-q}-rollback-drill.md`.

## Relacionado

- Fase 06 — `rollback-strategy.md` (automático).
- Fase 06 — `cd-production-oci.yml`.
- [incident-response-oci.md](incident-response-oci.md).

## Changelog

- 2026-04-17 — v1 inicial.
