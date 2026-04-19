# Plano Macro — Ambientes (sqa / uat / pro)

**Arquiteto Principal:** Gustavo Armoa

## Objetivo

Definir o propósito, a postura de segurança, o sizing e os gates de
governança dos 3 ambientes do track Basa. Serve de contrato entre
Terraform, Helm, pipelines, runbooks e ISMS.

## Os três ambientes

| Env | Nome completo | Propósito | Quem usa |
|---|---|---|---|
| **sqa** | System Quality Assurance | Integração contínua do time. Recebe merge em `develop`. QA/engineering validam comportamento, performance e integrações. | Engenharia + QA |
| **uat** | User Acceptance Testing | Pré-produção validada por stakeholders de negócio/clientes. Recebe promoção controlada a partir de sqa via branch `staging`. | Product + clientes-piloto + Security |
| **pro** | Production | Tráfego real. Recebe tag `v*.*.*` com aprovação de 2 reviewers. | Clientes finais |

## Branches e pipelines por env

| env | branch / ref de trigger | workflow |
|---|---|---|
| sqa | push em `develop` | `cd-sqa-oci.yml` |
| uat | push em `staging` | `cd-uat-oci.yml` |
| pro | tag `v*.*.*` + `workflow_dispatch` | `cd-pro-oci.yml` |

> Nomes de branches git (`develop`, `staging`, `main`) permanecem
> inalterados; apenas os identificadores de env (sqa/uat/pro) são usados
> em recursos cloud, workflows e secrets.

## Compartments OCI

```
tenancy root
└── revenu-platform
    ├── gateway-basa-sqa
    ├── gateway-basa-uat
    └── gateway-basa-pro
```

Policies escritas com `in compartment id ${compartment}` — impede
vazamento cross-env por erro (A.8.31 — Separation of environments).

## Rede (VCN CIDRs)

| Env | VCN CIDR | App subnet | LB subnet | Bastion subnet |
|---|---|---|---|---|
| sqa | `10.40.0.0/16` | `10.40.0.0/20` | `10.40.16.0/24` | `10.40.17.0/28` |
| uat | `10.41.0.0/16` | `10.41.0.0/20` | `10.41.16.0/24` | `10.41.17.0/28` |
| pro | `10.42.0.0/16` | `10.42.0.0/20` | `10.42.16.0/24` | `10.42.17.0/28` |

Reserva `10.40–10.49` para o track Basa.

## Domínios

| Env | Route host | Zona DNS |
|---|---|---|
| sqa | `gateway.sqa.oci.allenty.io` | `sqa.oci.allenty.io` |
| uat | `gateway.uat.oci.allenty.io` | `uat.oci.allenty.io` |
| pro | `gateway.oci.allenty.io` | `oci.allenty.io` |

Delegação NS de cada subzona feita na zona pai `allenty.io`
(runbook Fase 08 `bootstrap-first-apply.md`).

## Dimensionamento

| Item | sqa | uat | pro |
|---|---|---|---|
| Region primária | `sa-saopaulo-1` | `sa-saopaulo-1` | `sa-saopaulo-1` |
| Region DR | — | — | `sa-vinhedo-1` (cold standby) |
| Masters | 3 × `VM.Standard.E4.Flex` 4 OCPU / 16 GB | idem | idem |
| Workers iniciais | 2 × 2 OCPU / 8 GB | 3 × 2 OCPU / 8 GB | 3 × 4 OCPU / 16 GB |
| Worker autoscaler | 2–4 | 3–6 | 3–8 |
| Replicas Gateway | 1 (HPA 1–3) | 2 (HPA 2–6) | 3 (HPA 3–10) |
| OCP version | 4.16.x | 4.16.x (mesma minor de pro) | 4.16.x (latest stable) |

## Security posture

| Controle | sqa | uat | pro |
|---|---|---|---|
| Vault protection | SOFTWARE | HSM | HSM (FIPS 140-2 L3) |
| OCIR tag immutability | false | false (exceto `v*.*.*-rc*`) | **true** (`v*.*.*` eterno) |
| Bastion TTL | 10800s (3h) | 10800s (3h) | 3600s (1h) |
| FIPS mode (cluster) | off | off | off v1 (ativável — gatilho em Fase 01) |
| Flow log retention | 30d | 60d | 90d + archive 7 anos |
| Prometheus retention | 14d | 14d | 14d + Thanos archive (opcional) |
| Loki log retention | 7d infra / 30d app | 7d / 30d | 7d / 30d / 90d audit + archive 7 anos |
| Trivy severity block | CRITICAL, HIGH | CRITICAL, HIGH | CRITICAL, HIGH, **MEDIUM** |
| Cosign sign obrigatório | não | **sim** | **sim** |
| SBOM attestation | não | **sim** | **sim** |
| SLSA provenance | não | **sim** | **sim** |
| Helm `--atomic` | não | **sim** | **sim** |
| Auto-rollback on failure | não | **sim** | **sim** |
| PDB | desabilitado | `maxUnavailable: 1` | `minAvailable: 2` |

## Governança e approvals

| Item | sqa | uat | pro |
|---|---|---|---|
| GitHub Environment | `sqa-oci` | `uat-oci` | `pro-oci` |
| Reviewers exigidos | 0 | 1 (recomendado) | **2 obrigatórios** |
| Branch/ref permitido | `refs/heads/develop` | `refs/heads/staging` | `refs/tags/v*.*.*` |
| Change ticket annotation | não | opcional | **obrigatório** |
| Wait timer | 0 | 0 | 5 min (janela de cancelamento) |
| Concurrency | cancel-in-progress | não cancela | não cancela |
| Smoke test pós-deploy | 1 request | 10 requests + latency | 30s contínuo, tolera ≤2 falhas |

## Observabilidade

| Camada | sqa | uat | pro |
|---|---|---|---|
| OpenShift Monitoring | on | on | on |
| PrometheusRule (alertas) | off (ruído alto) | on | on |
| Alertmanager → Slack | `#gateway-alerts-sqa` | `#gateway-alerts-uat` | `#gateway-critical` + email oncall |
| OCI Monitoring bridge | off | on (métricas) | on (métricas + logs) |
| Grafana dashboards | compartilhado (`gateway-observability` namespace) | idem | idem |
| Trace sampling | 10% head | 10% head + tail (errors/slow) | 10% head + tail |
| ACS (StackRox) | off | off | off v1 (plano em Fase 05) |
| Compliance Operator | opcional | on (CIS OpenShift) | on (CIS OpenShift) |

## Compliance gates por env (ISO 27001)

| Controle | sqa | uat | pro |
|---|---|---|---|
| A.5.28 Evidence collection | daily report genérico | daily + drill | daily + archive 7 anos |
| A.5.30 BC readiness | N/A | N/A | DR cross-region (Fase 08) |
| A.5.33 Record retention | 30 dias | 90 dias | 7 anos |
| A.5.37 Documented procedures | runbook leve | runbook completo | runbook + drill trimestral |
| A.8.24 Crypto | TLS edge + SOFTWARE KMS | TLS edge + HSM KMS | TLS edge + HSM KMS + FIPS-ready |
| A.8.31 Env separation | compartment dedicado | compartment dedicado | compartment dedicado |
| A.8.32 Change management | push livre | push com review | tag + 2 reviewers + ticket |
| Audit logs OCI | 30d | 60d | 90d + archive 7 anos |

## Custos estimados (mensal, referência v1)

| Item | sqa | uat | pro |
|---|---|---|---|
| Masters OCP | ~$210 | ~$210 | ~$210 |
| Workers (iniciais) | ~$70 | ~$105 | ~$280 |
| Vault | SOFTWARE ~$2 | HSM ~$24 | HSM ~$24 |
| Load Balancers | ~$20 | ~$20 | ~$40 |
| Storage + egress | ~$20 | ~$40 | ~$100 |
| Observabilidade (Loki, Thanos) | ~$10 | ~$30 | ~$80 |
| Bridge OCI Monitoring/Logging | — | ~$25 | ~$125 |
| **Total estimado** | **~$350/mês** | **~$460/mês** | **~$900/mês** |

> Otimização sqa: stop/start noturno reduz ~60% (runbook Fase 08).

## Cronograma de rollout

| Marco | Duração | Entregável |
|---|---|---|
| **M1 — sqa bootstrap** | 2 sprints | Terraform apply + OCP install + primeiro deploy de Gateway; smoke pass |
| **M2 — uat bootstrap** | 1 sprint | Espelho de sqa com HSM + Cosign + SBOM + PrometheusRule |
| **M3 — Validação uat** | 2–4 sprints | Stakeholders de negócio exercitam `gateway.uat.oci.allenty.io`; Trivy MEDIUM clean; drill de rollback |
| **M4 — pro bootstrap** | 1 sprint | Terraform apply + OCP install; ainda sem tráfego real |
| **M5 — pro go-live** | 1 sprint | Cutover de DNS / clientes; 2 reviewers aprovação; drill IR + DR tabletop |
| **M6 — DR cross-region** | 1 sprint | Capacity reservation `sa-vinhedo-1` + runbook testado em tabletop |

## Compliance entre envs

1. **uat precisa ser "mesmo chart, mesmos operators, mesmos controles" de pro** — só muda sizing e intensidade de gates. Divergência em uat invalida-o como pré-prod.
2. **sqa pode divergir** em: sizing, logs verbosos, ACS off, Trivy não bloqueia MEDIUM. Nunca divergir em: naming, namespaces, NetworkPolicy, SCC.
3. **Qualquer release em pro passou por uat** — branch protection em `main` exige PR aprovado vindo de `staging` (uat).

## Matriz de responsabilidade

| Ação | sqa | uat | pro |
|---|---|---|---|
| Criar env (bootstrap) | SRE Lead | SRE Lead + ISO Lead | SRE Lead + ISO Lead + Platform Owner |
| Deploy rotineiro | CI automático | CI automático (opcional review) | CI + 2 reviewers + change ticket |
| Rollback manual | DevEx on-call | DevEx on-call | gateway-platform-admins (1 aprovador) |
| Destroy | SRE Lead | SRE Lead (com janela) | **Proibido** fora de DR catastrófico |
| Access via bastion | qualquer engenheiro | engenheiros + SRE | SRE + Security Lead (TTL 1h) |

## Referências para outras fases

- Sizing detalhado e ordem de apply: `02-iac-terraform-oci/environments.md`.
- Naming de recursos: `00-foundation/naming-conventions.md`.
- Security posture: `05-security-supplychain/README.md`.
- Pipelines CI/CD: `06-cicd-github-actions/README.md`.
- Rollback e DR: `08-runbooks/rollback.md`, `08-runbooks/dr-failover-cross-region.md`.
- Risk register por env (novos riscos macro B-R01..B-R04): `07-iso27001/risk-register-delta.md`.

## Controles ISO 27001 tocados

- Cl. 4.3 — Escopo ISMS (sqa + uat + pro cobertos).
- A.5.8 — Information security in project management (este plano).
- A.5.15 — Access control (matriz de responsabilidade).
- A.8.31 — Separation of environments.
- A.8.32 — Change management (gates por env).

## Checklist de adoção deste plano

- [ ] Aprovação do Platform Owner + ISO Lead.
- [x] Rename `dev/staging/prod` → `sqa/uat/pro` propagado nas Fases 02..08.
- [ ] Compartments OCI `gateway-basa-{sqa,uat,pro}` criados.
- [ ] GitHub Environments `sqa-oci` / `uat-oci` / `pro-oci` configurados
      com reviewers e branch protection.
- [ ] Zonas DNS `sqa.oci.allenty.io`, `uat.oci.allenty.io`, `oci.allenty.io`
      delegadas.
- [ ] Secrets GitHub renomeados (`OCI_REGION_SQA`, `OCIR_REPO_SQA`, ...).
- [ ] Namespaces OpenShift `gateway-sqa`, `gateway-uat`, `gateway-pro`
      criados com labels PSA.
- [ ] Cronograma M1..M6 validado com leads.

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
