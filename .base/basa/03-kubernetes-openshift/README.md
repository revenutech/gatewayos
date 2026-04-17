# Fase 03 — Kubernetes / OpenShift

Especificação do chart Helm e manifests OpenShift-flavored para o Gateway
no track Basa: **Route** (em vez de Ingress), **SCC** (SecurityContextConstraints),
**NetworkPolicy compatível com OVN-Kubernetes**, **ServiceMonitor** do
Prometheus Operator nativo do OpenShift, **HPA** e **PDB**.

## Arquivos

| Documento | Foco |
|---|---|
| [helm-chart-structure.md](helm-chart-structure.md) | Chart único ou chart separado, templates novos, valores condicionais |
| [route-vs-ingress.md](route-vs-ingress.md) | OpenShift Route — edge, passthrough, reencrypt, TLS, redirects |
| [scc-securitycontext.md](scc-securitycontext.md) | SCC restricted-v2 vs custom; compat com UID random |
| [networkpolicy-ovn.md](networkpolicy-ovn.md) | NetworkPolicy em OVN-K; ingress/egress; namespace egress |
| [servicemonitor.md](servicemonitor.md) | ServiceMonitor no Prometheus Operator OCP; PrometheusRule |
| [hpa-pdb.md](hpa-pdb.md) | HorizontalPodAutoscaler + PodDisruptionBudget |
| [values-per-env.md](values-per-env.md) | `values-oci-{dev,staging,prod}.yaml` — estrutura e defaults |

## Equivalência com track GCP

| GCP (atual) | Basa |
|---|---|
| `k8s/helm/gateway/templates/ingress.yaml` (GKE Ingress) | `templates/route.yaml` (OpenShift Route) |
| `k8s/helm/gateway/templates/managed-certificate.yaml` | `templates/certificate.yaml` (cert-manager) |
| `k8s/helm/gateway/templates/backend-config.yaml` (GCP) | N/A (Route cobre health check + drain) |
| `k8s/helm/gateway/templates/networkpolicy.yaml` (Calico) | `templates/networkpolicy.yaml` (OVN-K — mesma API, checar egress) |
| `values-gcp-{env}.yaml` | `values-oci-{env}.yaml` |
| `securityContext` do deployment | `SCC` do OpenShift + annotations para UID random |
| HPA, PDB, ServiceMonitor, ServiceAccount, Deployment | **Reutilizados sem mudanças estruturais** |

## Princípio guia — chart único

Mesmo chart Helm, valores trocam. Novos templates (Route, SCC, Certificate)
são condicionais (`{{- if .Values.openshift.enabled }}`). Assim:

- `values-gcp-*.yaml` deixa `openshift.enabled: false` → renderiza Ingress + ManagedCertificate.
- `values-oci-*.yaml` deixa `openshift.enabled: true` → renderiza Route + Certificate + SCC.

ADR implícito registrado em `helm-chart-structure.md`.

## Objetivo: paridade funcional

| Comportamento | GCP | Basa |
|---|---|---|
| HTTPS externo com cert gerenciado | GKE ManagedCertificate | cert-manager + Route edge |
| HTTP → HTTPS redirect | FrontendConfig | Route `insecureEdgeTerminationPolicy: Redirect` |
| Readiness/liveness | `/__health` | idem |
| Autoscaling CPU/mem | HPA | HPA (sem mudança) |
| Max unavailable rollout | PDB | PDB (sem mudança) |
| Prometheus scrape | ServiceMonitor | ServiceMonitor (mesma API) |
| NetworkPolicy | Calico | OVN-K (mesma API — checar egress específico) |
| Pod security | securityContext + PSA | SCC restricted-v2 (mesma postura) |
| Init container | Não | Opcional — `permissions-init` se precisar preparar filesystem |

## Namespaces

- Dev/staging/prod: `gateway-dev`, `gateway-staging`, `gateway-prod` (ver
  `naming-conventions.md` da Fase 00).
- Namespaces criados **pelo cluster-bootstrap** (Fase 02 post-install CR)
  com labels:
  ```
  pod-security.kubernetes.io/enforce: restricted
  platform.revenu/env: {env}
  platform.revenu/track: basa
  ```

## Checklist de fechamento da Fase 03

- [ ] Chart único com templates condicionais validado via `helm template`.
- [ ] Route funcional em OCP dev (após Fase 02 apply).
- [ ] cert-manager emitindo cert LE staging em dev.
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
