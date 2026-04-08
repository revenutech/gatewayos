# Kubernetes Manifests

All manifests at `k8s/manifests/`.

## Core Resources

### deployment.yaml

| Setting | Value |
|---------|-------|
| Replicas | 2 |
| Strategy | RollingUpdate (maxSurge=1, maxUnavailable=0) |
| Revision history | 5 |
| Service account | krakend (automount disabled) |
| Security context | non-root (1000:1000), seccomp RuntimeDefault |
| Termination grace | 30s |
| Pod anti-affinity | Prefer different nodes |

**Containers:**

| Container | Image | Ports | CPU | Memory |
|-----------|-------|-------|-----|--------|
| krakend | devopsfaith/krakend:2.9.4 | 8080, 8090 | 250m-1000m | 128Mi-512Mi |
| envoy-grpc-transcoder | envoyproxy/envoy:v1.31 | 8085 | 50m-200m | 64Mi-128Mi |

Both containers: readOnly rootFS, drop ALL capabilities, no privilege escalation.

**Volumes:**
- config (ConfigMap) → /etc/krakend
- mtls-certs (Secret) → /etc/krakend/tls
- tmp (emptyDir, 50Mi) → /tmp
- envoy-config (ConfigMap) → /etc/envoy
- envoy-proto (ConfigMap) → /etc/envoy/proto
- envoy-tmp (emptyDir, 10Mi) → /tmp

**Config hash annotation:** `checksum/config` triggers rolling restart when config changes.

### service.yaml

ClusterIP service exposing ports 8080 (http) and 8090 (metrics).

### ingress.yaml

- Ingress class: nginx
- TLS: cert-manager with letsencrypt-prod
- Host: api.revenu.com.br
- SSL redirect: forced
- Body size: 10m
- Timeouts: 30s read/send
- Rate limit: 100r/s per IP (burst 200) at nginx level
- GeoIP headers: X-Geo-Country, X-Geo-Continent
- Geo-blocking support (configurable)

### serviceaccount.yaml

ServiceAccount `krakend` with minimal RBAC.

## Scaling & Reliability

### hpa.yaml

| Setting | Value |
|---------|-------|
| Min replicas | 2 |
| Max replicas | 8 |
| CPU target | 60% utilization |
| Memory target | 75% utilization |
| Scale up | Instant (100%/15s or +4 pods/15s, max policy) |
| Scale down | Conservative (10%/60s, 300s stabilization) |

### pdb.yaml

maxUnavailable: 1 — ensures at least 1 pod available during disruptions.

## Monitoring

### servicemonitor.yaml

Prometheus scrape config: port `metrics` (8090), path `/__metrics`, interval 15s, timeout 10s.

### prometheusrule.yaml

8 alerts in 2 groups:

**krakend.rules:**
1. KrakenDHighErrorRate — >5% 5xx for 5m (critical)
2. KrakenDCircuitBreakerOpen — any CB open for 1m (warning)
3. KrakenDHighLatency — p95 >1s for 5m (warning)
4. KrakenDRateLimitSpike — >100/s 429s for 2m (info)

**krakend.business.rules:**
5. KrakenDTenantErrorBudgetBurn — >1% per-tenant 5xx over 1h (warning)
6. KrakenDNoRevenueEvents — no postings/settlements/pix for 30m (warning)
7. KrakenDAuthFailureSpike — >50/s 401/403 for 5m (warning)
8. KrakenDTierRateLimitExhaustion — >10/s 429 per tier for 5m (info)

### prometheusrule-compliance.yaml

6 ISO-annotated alerts:
1. CertExpiringIn30Days (A.8.24, warning)
2. CertExpiringIn7Days (A.8.24, critical)
3. ConfigValidationFailure (A.8.9, warning)
4. AccessControlAnomaly (A.5.15, warning)
5. CapacityAtMaximum (A.8.6, warning)
6. ReducedRedundancy (A.8.14, critical)

## Other Manifests

| Manifest | Purpose |
|----------|---------|
| configmap.yaml | KrakenD config injection |
| config-reloader.yaml | Dynamic config reload scripts |
| envoy-grpc-configmap.yaml | Envoy transcoder configuration |
| geoip-configmap.yaml | GeoIP database |
| mtls-certificates.yaml | mTLS cert provisioning |
| ws-proxy-ingress.yaml | WebSocket proxy ingress |
| data-retention-cronjob.yaml | Scheduled data cleanup |
| grafana-dashboard-security.json | Security Grafana dashboard |
