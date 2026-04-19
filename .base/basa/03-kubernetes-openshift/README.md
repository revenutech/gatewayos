# Fase 03 — Kubernetes / OpenShift

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
