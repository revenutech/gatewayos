# Testing

## Config Validation

### KrakenD Check

Validates template syntax, JSON structure, and schema compliance:

```bash
docker run --rm \
  -v ./krakend:/etc/krakend \
  -e FC_ENABLE=1 \
  -e FC_SETTINGS=/etc/krakend/settings \
  -e FC_PARTIALS=/etc/krakend/partials \
  -e FC_TEMPLATES=/etc/krakend/templates \
  devopsfaith/krakend:2.13 \
  check -c /etc/krakend/krakend.tmpl
```

### Config Audit

Comprehensive audit checking environment consistency, security settings, and CORS:

```bash
bash tools/config-audit/audit.sh --strict
```

### JSON Linting

Validates JSON syntax of all settings files:

```bash
for f in $(find krakend/settings -name '*.json'); do
  python3 -m json.tool "$f" > /dev/null
done
```

## OpenAPI Generation

Generates OpenAPI specification from endpoint definitions:

```bash
pip install -r tools/openapi-generator/requirements.txt
python tools/openapi-generator/generate.py \
  --endpoints-dir krakend/endpoints \
  --output openapi.yaml
```

## Enterprise Feature Tests

Script: `tests/test-enterprise-features.sh`

35 tests covering Lua-based enterprise features:
- 19 PASS — features fully operational
- 16 SKIP — features requiring external dependencies (Redis, specific backends)

## Container Security

### Trivy Scan

```bash
docker build -t revenu-gateway:scan .
trivy image --severity CRITICAL,HIGH revenu-gateway:scan
```

### SBOM Generation

```bash
trivy image --format cyclonedx --output sbom.json revenu-gateway:scan
```

## Test Endpoints

Two endpoints available for integration testing:

### GET /v1/test/echo

Lua middleware test. Returns request details processed through `test_minimal.lua` pre/post proxy hooks. No auth required.

### POST /v1/test/validate

Schema validation test. Processes request body through Lua middleware. No auth required.

Both endpoints proxy to `ledgeros/health` as a backend stub.

## Health Checks

| Endpoint | Purpose | Backend |
|----------|---------|---------|
| `GET /__health` | KrakenD liveness | Internal |
| `GET /__ready` | Backend readiness | ledgeros:8081/health |
| `GET /__metrics` | Prometheus metrics | Internal |

## CI Pipeline Testing

Tests run automatically in CI (`.github/workflows/ci.yml`):
1. KrakenD config check
2. Config audit (--strict)
3. OpenAPI generation
4. Docker build
5. Trivy scan (CRITICAL + HIGH)
6. SBOM generation
