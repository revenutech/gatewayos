# Network Policies

Kubernetes NetworkPolicies implement default-deny with explicit allow rules.

## Policy Files

| File | Purpose |
|------|---------|
| `k8s/policies/krakend-ingress.yaml` | Inbound traffic to gateway |
| `k8s/policies/krakend-egress.yaml` | Outbound traffic from gateway |
| `k8s/policies/krakend-ws-ingress.yaml` | WebSocket ingress |
| `k8s/policies/krakend-ip-filter.yaml` | IP-based filtering |

## Ingress Policy

Controls who can reach the gateway pods.

| Source | Namespace | Port | Purpose |
|--------|-----------|------|---------|
| ingress-nginx | ingress-nginx | 8080/TCP | Client traffic via NGINX ingress controller |
| prometheus | monitoring | 8090/TCP | Metrics scraping |

All other inbound traffic is **denied by default**.

## Egress Policy

Controls what the gateway can connect to.

| Destination | Namespace/Selector | Port(s) | Purpose |
|-------------|-------------------|---------|---------|
| kube-dns | kube-system | 53/UDP, 53/TCP | DNS resolution |
| LedgerOS | app: ledgeros | 8081/TCP, 9081/TCP | HTTP + gRPC |
| Paymentos | app: paymentos | 8082/TCP | Payments |
| AtmOS | app: atmos | 8088/TCP | ATM |
| Identos | app: identos | 8091/TCP | Identity |
| OnboardOS | app: onboardos | 8092/TCP | Onboarding |
| AccountOS | app: accountos | 8093/TCP | Accounts |
| FinanceOS | app: financeos | 8095/TCP | Finance |
| Keycloak | keycloak namespace | 8443/TCP, 8080/TCP | JWKS endpoint |
| Redis | app: redis | 6379/TCP | Rate limiting, caching |
| OTel Collector | monitoring namespace | 4317/TCP | Telemetry export |

All other outbound traffic is **denied by default**.

## Security Model

```
                    Default Deny
                         |
     Ingress ────────────+──────────── Egress
     (allow)             |              (allow)
        |                |                |
  ingress-nginx     krakend pod      backends only
  prometheus            |            + keycloak
                        |            + redis
                        |            + otel-collector
                        |            + kube-dns
```

## Namespace Isolation

- Gateway selects backends by pod label (`app.kubernetes.io/name`)
- Cross-namespace access (Keycloak, monitoring) uses `namespaceSelector`
- Backends are in the same namespace (default) or in `ledgeros-{env}` namespace

## IP Filtering

The `krakend-ip-filter.yaml` policy provides additional IP-based filtering at the network level, complementing the Nginx ingress CIDR allowlisting.

## ISO 27001 Reference

- **A.8.20** — Network security (network segmentation)
- **A.8.21** — Security of network services
- **A.13.1.1** — Network controls
