# Fase 03 — Kubernetes / OpenShift

**Arquiteto Principal:** Gustavo Armoa

Especificação do chart Helm e manifests OpenShift-flavored para o Gateway
no track Basa: **Route**, **SCC** (SecurityContextConstraints),
**NetworkPolicy compatível com OVN-Kubernetes**, **ServiceMonitor** do
Prometheus Operator nativo do OpenShift, **HPA** e **PDB**.

## Arquivos

| Documento | Foco |
|---|---|
| [helm-chart-structure.md](helm-chart-structure.md) | Estrutura do chart, templates, valores por env |
| [route-vs-ingress.md](route-vs-ingress.md) | OpenShift Route — edge, passthrough, reencrypt, TLS, redirects |
| [scc-securitycontext.md](scc-securitycontext.md) | SCC restricted-v2 vs custom; compat com UID random |
| [networkpolicy-ovn.md](networkpolicy-ovn.md) | NetworkPolicy em OVN-K; ingress/egress; namespace egress |
| [servicemonitor.md](servicemonitor.md) | ServiceMonitor no Prometheus Operator OCP; PrometheusRule |
| [hpa-pdb.md](hpa-pdb.md) | HorizontalPodAutoscaler + PodDisruptionBudget |
| [values-per-env.md](values-per-env.md) | `values-oci-{sqa,uat,pro}.yaml` — estrutura e defaults |

## Comportamento esperado

| Área | Implementação |
|---|---|
| HTTPS externo com cert gerenciado | cert-manager + Route edge |
| HTTP → HTTPS redirect | Route `insecureEdgeTerminationPolicy: Redirect` |
| Readiness/liveness | `/__health` |
| Autoscaling CPU/mem | HPA |
| Max unavailable rollout | PDB |
| Prometheus scrape | ServiceMonitor (OpenShift User Workload Monitoring) |
| NetworkPolicy | OVN-K (`networking.k8s.io/v1`) |
| Pod security | SCC `restricted-v2` + PSA `restricted` |
| Init container | Opcional — `permissions-init` se precisar preparar filesystem |

## Namespaces

- sqa/uat/pro: `gateway-sqa`, `gateway-uat`, `gateway-pro` (ver
  `naming-conventions.md` da Fase 00).
- Namespaces criados **pelo cluster-bootstrap** (Fase 02 post-install CR)
  com labels:
  ```
  pod-security.kubernetes.io/enforce: restricted
  platform.revenu/env: {env}
  platform.revenu/track: basa
  ```

## Checklist de fechamento da Fase 03

- [ ] Chart com templates validado via `helm template` para todos os envs.
- [ ] Route funcional em OCP sqa (após Fase 02 apply).
- [ ] cert-manager emitindo cert LE staging em sqa.
- [ ] SCC adequado confirmado (pod roda sem erros).
- [ ] NetworkPolicy OVN-K testada (conectividade do Gateway para
      backends + bloqueio cross-namespace).
- [ ] ServiceMonitor scrapeado pelo Prometheus Operator OCP.
- [ ] HPA ativando-se em stress test.

## Controles ISO 27001

- A.8.9 — Configuration management (Helm + values versionados).
- A.8.14 — Redundancy (HPA + PDB).
- A.8.16 — Monitoring activities (ServiceMonitor).
- A.8.20 — Networks security (NetworkPolicy).
- A.8.22 — Segregation of networks (namespaces + NetPol).
- A.8.24 — Cryptography (TLS Route + cert-manager).
- A.8.2 — Privileged access (SCC restringe capabilities).

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
