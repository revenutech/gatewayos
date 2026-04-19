# Runbook — Rollback Manual

**Arquiteto Principal:** Gustavo Armoa

## Objetivo

Executar rollback manual do Gateway em OCP quando: (a) rollback automático
não disparou, (b) degradação apareceu pós-deploy, (c) feature toggle
obrigou reverter release.

Complementa [Fase 06 `rollback-strategy.md`](../06-cicd-github-actions/rollback-strategy.md).

## Owner / Backup

- **Owner:** DevEx (on-call).
- **Backup:** SRE Lead.
- **Aprovador (pro):** 1 reviewer de `gateway-platform-admins`.

## Trigger

- Alert `GatewayHighErrorRate` > 5 min sem auto-rollback.
- Reporte de cliente indicando degradação.
- Incidente de segurança atrelado ao release atual (ex: CVE recém-publicado).
- Feature toggle precisa ser revertida (usualmente via código + redeploy).

## Pre-checks

- [ ] Confirmar sintoma real via Grafana / Loki / Alertmanager — não é falso positivo.
- [ ] Identificar revisão estável anterior via `helm history`.
- [ ] Confirmar que imagem da revisão anterior ainda existe em OCIR
      (pro: imagens `v*.*.*` são imutáveis, sempre disponíveis).
- [ ] Abrir ticket de incidente (Linear / Jira).
- [ ] Notificar `#gateway-critical` no Slack **antes** do rollback.
- [ ] Aprovador disponível (pro).

## Procedimento

### 1. Fetch kubeconfig

```
oci secrets secret-bundle get \
  --secret-id $OCP_KUBECONFIG_SECRET_OCID_PRO \
  --query 'data."secret-bundle-content".content' --raw-output \
  | base64 -d > ~/.kube/config
chmod 600 ~/.kube/config
```

### 2. Listar revisões

```
helm history gateway -n gateway-pro --max 20
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
helm rollback gateway 22 -n gateway-pro \
  --wait --timeout 5m
```

Ou para a revisão anterior imediata:

```
helm rollback gateway 0 -n gateway-pro \
  --wait --timeout 5m
```

`0` = revisão anterior automaticamente.

### 4. Verificar rollout

```
kubectl -n gateway-pro rollout status deploy/gateway --timeout=5m

oc get pods -n gateway-pro -l app.kubernetes.io/name=gateway
oc get deploy gateway -n gateway-pro -o yaml \
  | grep 'image:'
```

Verificar que a tag da imagem voltou para `v1.3.5` (ou correspondente).

### 5. Smoke

```
HOST=$(oc get route gateway -n gateway-pro -o jsonpath='{.spec.host}')
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

Se a imagem alvo do rollback foi purged (não deveria acontecer em pro
com immutable tags):

1. **Rebuild from git:**
   ```
   git checkout v1.3.5
   gh workflow run cd-pro-oci.yml --ref v1.3.5 \
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
- [ ] Fix em sqa → uat → re-deploy pro.

## Evidência a gerar

- `helm history` antes + depois em
  `/compliance/evidences/runbooks/{yyyy-mm-dd}-rollback-{env}.md`.
- Timeline com timestamp + action + actor.
- Screenshot Grafana do período (5xx curve).
- Ticket link.

## Escalação

- Rollback `helm rollback` falha (`error: release gateway failed`):
  → Platform Owner, considerar `helm uninstall` + `helm install` como
  último recurso **somente em sqa**.
- Prod em degradação severa e rollback não resolve → invocar
  [incident-response-oci.md](incident-response-oci.md).
- Múltiplos rollbacks em <24h → freeze de releases + post-mortem
  mandatório.

## Drill

**Trimestral em uat:**
1. Deploy intencional com `image.tag=<known-broken-image>`.
2. Validar rollback manual dispara em <5 min.
3. Registrar tempo + passos em
   `/compliance/evidences/runbooks/drills/{yyyy-q}-rollback-drill.md`.

## Relacionado

- Fase 06 — `rollback-strategy.md` (automático).
- Fase 06 — `cd-pro-oci.yml`.
- [incident-response-oci.md](incident-response-oci.md).

## Changelog

- 2026-04-17 — v1 inicial.

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
