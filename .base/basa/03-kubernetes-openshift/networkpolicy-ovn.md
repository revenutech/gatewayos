# NetworkPolicy em OVN-Kubernetes

## Objetivo

Replicar a postura de NetworkPolicy do track GCP (Calico) no OpenShift on
OCI, que usa **OVN-Kubernetes (OVN-K)** como CNI default. Mesma API
`networking.k8s.io/v1` — comportamento 99% compatível, com detalhes sobre
egress e namespace selectors.

## Compatibilidade Calico ↔ OVN-K

| Feature | Calico | OVN-K | Nota |
|---|---|---|---|
| `podSelector` ingress | ✅ | ✅ | idem |
| `podSelector` egress | ✅ | ✅ | idem |
| `namespaceSelector` | ✅ | ✅ | OVN-K requer label `kubernetes.io/metadata.name` |
| `ipBlock` (CIDR) egress | ✅ | ✅ | idem |
| `named port` | ✅ | ✅ | idem |
| DNS egress | ✅ | ✅ (necessita allow 53/udp + 53/tcp para kube-dns) |
| Default deny (ingress) | ✅ | ✅ | |
| Egress policies | ✅ | ✅ (OCP 4.10+) | |
| Admin NetworkPolicy (ANP) | ❌ | ✅ (cluster-scoped, prioridade) | opcional em Fase 05 |
| Calico Global NetworkPolicy | ✅ | ❌ | migrar para ANP (OVN-K) se precisar |

**OVN-K tem paridade para o chart atual.** Ajustes: explicitar DNS egress,
usar label `kubernetes.io/metadata.name` em namespaceSelector.

## Política default do namespace

Aplicar **deny-all ingress + deny-all egress** por namespace, depois
allow explícitos:

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-all
  namespace: gateway-{env}
spec:
  podSelector: {}
  policyTypes:
    - Ingress
    - Egress
```

Aplicado uma vez por namespace via Helm (ou bootstrap).

## NetworkPolicy do Gateway — `templates/networkpolicy.yaml`

### Ingress (quem pode chamar o Gateway)

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: {{ include "gateway.fullname" . }}-ingress
  namespace: {{ .Release.Namespace }}
spec:
  podSelector:
    matchLabels:
      app.kubernetes.io/name: gateway
  policyTypes:
    - Ingress
  ingress:
    # HAProxy Router (OpenShift Ingress Controller)
    - from:
        - namespaceSelector:
            matchLabels:
              kubernetes.io/metadata.name: openshift-ingress
      ports:
        - port: 8080
          protocol: TCP
    # Prometheus (cluster-monitoring)
    - from:
        - namespaceSelector:
            matchLabels:
              kubernetes.io/metadata.name: openshift-monitoring
      ports:
        - port: 8090
          protocol: TCP
    # HealthCheck / debug via bastion (opcional, apenas dev)
    {{- if eq .Values.krakend.env "dev" }}
    - from:
        - namespaceSelector:
            matchLabels:
              kubernetes.io/metadata.name: gateway-dev
      ports:
        - port: 8080
          protocol: TCP
    {{- end }}
```

### Egress (para onde o Gateway chama)

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: {{ include "gateway.fullname" . }}-egress
  namespace: {{ .Release.Namespace }}
spec:
  podSelector:
    matchLabels:
      app.kubernetes.io/name: gateway
  policyTypes:
    - Egress
  egress:
    # DNS (kube-dns)
    - to:
        - namespaceSelector:
            matchLabels:
              kubernetes.io/metadata.name: openshift-dns
      ports:
        - port: 53
          protocol: UDP
        - port: 53
          protocol: TCP
    # Backends do gateway (mesmo namespace ou cross-ns)
    {{- range .Values.networkPolicy.backends }}
    - to:
        - namespaceSelector:
            matchLabels:
              kubernetes.io/metadata.name: {{ .namespace }}
          podSelector:
            matchLabels:
              app.kubernetes.io/name: {{ .app }}
      ports:
        - port: {{ .port }}
          protocol: TCP
    {{- end }}
    # Keycloak JWKS (externo)
    - to:
        - ipBlock:
            cidr: 0.0.0.0/0
            except:
              - 10.0.0.0/8
              - 172.16.0.0/12
              - 192.168.0.0/16
      ports:
        - port: 443
          protocol: TCP
    # OCI Vault (para ESO) e OCIR (para pull, se kubelet passa pelo pod — normalmente não)
```

## Valores dos backends — `values-oci-{env}.yaml`

```yaml
networkPolicy:
  enabled: true
  backends:
    - namespace: ledgeros-{env}
      app: ledgeros
      port: 8081
    - namespace: paymentos-{env}
      app: paymentos
      port: 8082
    - namespace: identos-{env}
      app: identos
      port: 8091
    - namespace: atmos-{env}
      app: atmos
      port: 8088
```

## Keycloak JWKS — externo

O Gateway faz JWKS fetch do Keycloak (externo ao cluster OCI na v1). Duas
opções:

1. **Allow egress para 0.0.0.0/0 porta 443** (com exclusões de ranges
   privadas) — simples, permite acesso a serviços externos.
2. **Allow egress para `FQDN` do Keycloak** — OVN-K suporta `EgressFirewall`
   CR (OpenShift specific) com DNS names. Mais restritivo.

V1: opção (1) para simplicidade; `EgressFirewall` com FQDN fica em Fase
05 (Security).

## EgressFirewall (OpenShift-specific, opcional)

```yaml
apiVersion: k8s.ovn.org/v1
kind: EgressFirewall
metadata:
  name: default
  namespace: gateway-{env}
spec:
  egress:
    - type: Allow
      to:
        dnsName: keycloak.revenu.com.br
    - type: Allow
      to:
        cidrSelector: 0.0.0.0/0
      ports:
        - protocol: TCP
          port: 53
    - type: Deny
      to:
        cidrSelector: 0.0.0.0/0
```

Vale em **complemento** à NetworkPolicy. Aplicado por namespace.

## AdminNetworkPolicy (ANP) — cluster-wide

OCP 4.14+. Substitui Calico Global NetPol. Ex: bloquear todo egress para
`kube-system` exceto API server. Ficará em Fase 05 como hardening opcional.

## Testes

1. **Ingress válido:** `curl` do Router namespace → gateway:8080 — 200.
2. **Ingress inválido:** `curl` de `default` namespace → gateway:8080 —
   timeout.
3. **Egress válido:** pod gateway → `ledgeros:8081` — 200.
4. **Egress inválido:** pod gateway → `paymentos:1234` — timeout.
5. **DNS:** pod gateway → `kubectl exec ... dig ledgeros.ledgeros-dev` —
   resolve.

Automatizar em CI com `kubectl run` temporário (Fase 06).

## Decisões de design

1. **Default deny** por namespace como baseline.
2. **NetworkPolicy por app** — o chart cria sua; outros apps fazem igual.
3. **Keycloak externo via `0.0.0.0/0`** na v1, `EgressFirewall` com FQDN
   em Fase 05.
4. **Sem Admin NetworkPolicy v1** — avaliar em hardening.

## Controles ISO 27001

- A.8.20 — Networks security.
- A.8.22 — Segregation of networks.
- A.8.23 — Web filtering (EgressFirewall).

## Checklist pronto-para-código

- [ ] Default-deny aplicado em cada namespace `gateway-*`.
- [ ] NetworkPolicy ingress permite Router + Monitoring.
- [ ] NetworkPolicy egress permite DNS + backends + Keycloak.
- [ ] Testes de conectividade automatizados (Fase 06).
- [ ] EgressFirewall documentado para Fase 05.
