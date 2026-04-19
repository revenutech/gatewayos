# Rollback Strategy

**Arquiteto Principal:** Gustavo Armoa

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
helm history gateway -n gateway-pro
helm rollback gateway <revision-num> -n gateway-pro
```

Detalhe completo no runbook em [`../08-runbooks/rollback.md`](../08-runbooks/rollback.md).

## Retention de revisões Helm

Helm mantém histórico em Secrets K8s (`sh.helm.release.v1.gateway.*`):

```
helm upgrade --history-max 20 ...
```

- **sqa:** 5 revisões.
- **uat:** 10.
- **pro:** 20 — cobre ~2 semanas de releases diárias.

Secrets rotacionam; não ocupam espaço significativo.

## Triggers de rollback automático (thresholds)

| Sinal | Threshold | Ação |
|---|---|---|
| Pod não `Ready` em `--timeout` | 10 min (pro) | `helm rollback 0` |
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

**Nunca** fazer `terraform state rm` ou rollback manual de state em pro.

Casos destrutivos (ex: `terraform destroy` acidental):
- Recuperar `terraform.tfstate` de versão anterior no bucket OCI (Fase 02).
- Runbook em Fase 08 — `08-runbooks/disaster-recovery.md`.

## Rollback de imagem + Helm combinado

Cenário: Helm rollback reverte para revision N-1, mas a imagem usada
naquela revision não está mais no OCIR (purged por retention).

Mitigação:
- **Retention agressiva em pro** — manter `v*.*.*` imutáveis para sempre
  (Fase 02).
- **Tag de release** garantida por 180 dias em uat.
- **sqa: aceitamos perda** (imagens são triviais de rebuild).

## Rollback em múltiplos envs (cascade)

Se bug chegou a uat + pro quase simultaneamente:

1. **Prod primeiro** (reduz impacto).
2. uat depois.
3. sqa mantém tag buggy para reprodução (debugging).

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
3. Release na GitHub marcada como `draft` ou `prerelease` se era pro.

## Permissions / who can rollback

- **CI automático:** service account do pipeline (já tem permissions para helm upgrade).
- **Manual:** membros de `gateway-platform-admins` (OCP RBAC + OCI group).
- **Break-glass:** Security Lead pode forçar rollback via bastion (auditoria extensa).

## Testes de rollback

Fire drill **trimestral** em uat:
1. Deploy intencionalmente broken (`image.tag=broken`).
2. Validar rollback auto dispara.
3. Medir tempo (target < 5 min).
4. Registrar evidência em management review.

## Decisões de design

1. **Helm atomic em uat+pro** — automático em falha de deploy.
2. **Rollback manual para degradação pós-deploy** — humano decide.
3. **Retention Helm pro = 20** revisões.
4. **Tags pro imutáveis para sempre** — evita "rollback impossível".
5. **Drill trimestral** — A.8.6 (capacity & drills).

## Controles ISO 27001

- A.5.24 — Information security incident management planning.
- A.5.26 — Response to incidents.
- A.5.30 — ICT readiness for business continuity.
- A.8.32 — Change management.
- A.8.14 — Redundancy of information processing facilities.

## Checklist pronto-para-código

- [ ] Helm history-max ajustado por env.
- [ ] Rollback auto testado em uat (fire drill).
- [ ] Runbook manual (Fase 08) referencia este doc.
- [ ] Slack #gateway-releases recebe notificações.
- [ ] Auto-ticket configurado (Linear API ou GitHub Issues).
- [ ] Permissions doc de quem pode rollback.

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
