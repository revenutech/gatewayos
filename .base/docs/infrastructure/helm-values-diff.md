# Helm Values Comparison

Differences across `values-gcp-dev.yaml`, `values-gcp-staging.yaml`, and `values-gcp-production.yaml`.

## Image

| Setting | Dev | Staging | Production |
|---------|-----|---------|------------|
| Repository | southamerica-east1-docker.pkg.dev/revenu-gateway-dev/gateway-dev/gateway | .../gateway-staging/.../gateway | .../gateway-production/.../gateway |
| Tag | dev-latest or dev-{sha} | staging-{sha} | v*.*.* (semver) |

## Replicas & Scaling

| Setting | Dev | Staging | Production |
|---------|-----|---------|------------|
| Replicas | 2 | 2 | 2 |
| HPA min | 2 | 2 | 2 |
| HPA max | 4 | 6 | 8 |
| CPU target | 60% | 60% | 60% |
| Memory target | 75% | 75% | 75% |

## Resources

| Setting | Dev | Staging | Production |
|---------|-----|---------|------------|
| KrakenD CPU request | 250m | 250m | 500m |
| KrakenD CPU limit | 1000m | 1000m | 2000m |
| KrakenD memory request | 128Mi | 128Mi | 256Mi |
| KrakenD memory limit | 512Mi | 512Mi | 1Gi |

## Ingress

| Setting | Dev | Staging | Production |
|---------|-----|---------|------------|
| Host | gateway.allenty.io | staging-api.revenu.com.br | api.revenu.com.br |
| TLS | ManagedCertificate | ManagedCertificate | ManagedCertificate |
| Ingress class | gce | gce | gce |

## KrakenD Settings

| Setting | Dev | Staging | Production |
|---------|-----|---------|------------|
| Settings env | dev | staging | prod |
| Log level | DEBUG | INFO | WARNING |
| Error messages | Verbose | Generic | Generic |

## Monitoring

| Setting | Dev | Staging | Production |
|---------|-----|---------|------------|
| ServiceMonitor | Enabled | Enabled | Enabled |
| PrometheusRules | Basic | Full | Full + Compliance |
| Grafana dashboards | Optional | Enabled | Enabled |
