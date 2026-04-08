# Local Development Setup

## Prerequisites

- Docker
- Docker Compose

## Quick Start

```bash
docker compose up
```

This starts:
- **KrakenD** on `:8080` (API) and `:8090` (metrics)
- **Envoy gRPC transcoder** on `:8085` (gRPC proxy) and `:9901` (Envoy admin)

KrakenD waits for Envoy to be healthy before starting (`depends_on: service_healthy`).

## Verify

```bash
# Health check (KrakenD internal)
curl http://localhost:8080/__health

# Readiness check (proxied to LedgerOS /health)
curl http://localhost:8080/__ready

# Prometheus metrics
curl http://localhost:8090/__metrics

# Envoy health
curl http://localhost:9901/ready
```

Note: `/__ready` will fail unless LedgerOS is running on `:8081`.

## Services

### KrakenD

| Setting | Value |
|---------|-------|
| Image | Built from Dockerfile |
| Ports | 8080 (API), 8090 (metrics) |
| Config | Live templates (FC_ENABLE=1) |
| Settings | `krakend/settings/dev.json` |
| Volume | `./krakend:/etc/krakend` |

Changes to `krakend/` are reflected after container restart — FC compiles templates at startup.

### Envoy gRPC Transcoder

| Setting | Value |
|---------|-------|
| Image | envoyproxy/envoy:v1.31-latest |
| Ports | 8085 (transcoder), 9901 (admin) |
| Config | `envoy/envoy-dev.yaml` |
| Proto | `envoy/proto/` |

## Config Validation

Validate without running:

```bash
docker run --rm \
  -v ./krakend:/etc/krakend \
  -e FC_ENABLE=1 \
  -e FC_SETTINGS=/etc/krakend/settings \
  -e FC_PARTIALS=/etc/krakend/partials \
  -e FC_TEMPLATES=/etc/krakend/templates \
  devopsfaith/krakend:2.9.4 \
  check -c /etc/krakend/krakend.tmpl
```

## Working with Backends

In Docker Compose, backends are reached by service name. If running backends locally outside Docker, update `krakend/settings/dev.json`:

```json
"backends": {
  "ledgeros_http": "http://host.docker.internal:8081",
  ...
}
```

## Rebuild

```bash
docker compose build   # Rebuild KrakenD image
docker compose up -d   # Restart
docker compose logs -f krakend  # Follow logs
```
