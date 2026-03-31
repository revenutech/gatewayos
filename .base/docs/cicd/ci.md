# CI Pipeline

File: `.github/workflows/ci.yml`
Triggers: push to main/develop, PR to main

## Jobs

```
validate ──┬──> config-audit
           ├──> openapi-generate
           ├──> docker-build ──> container-security
           └──> config-hash (main only)
```

### 1. validate

KrakenD config check via Docker + JSON linting of settings files.

```bash
docker run --rm -v ./krakend:/etc/krakend \
  -e FC_ENABLE=1 ... \
  devopsfaith/krakend:2.13 check -c /etc/krakend/krakend.tmpl
```

### 2. config-audit

Runs `tools/config-audit/audit.sh --strict`. Checks environment consistency, security settings, CORS configuration.

### 3. openapi-generate

Generates OpenAPI spec from endpoint definitions:
```bash
python tools/openapi-generator/generate.py \
  --endpoints-dir krakend/endpoints --output openapi.yaml
```
Uploads `openapi.yaml` as artifact.

### 4. docker-build

Builds Docker image to verify Dockerfile and multi-stage compilation work.

### 5. container-security

- **Trivy scan:** CRITICAL + HIGH severity, fails on findings (ignore unfixed)
- **SBOM generation:** CycloneDX format, uploaded as artifact
- ISO refs: A.5.21 (supply chain), A.8.8 (vulnerability management)

### 6. config-hash (main only)

Computes SHA256 hash of all krakend config files. Updates `deployment.yaml` with `checksum/config` annotation for rolling restarts.

```bash
HASH=$(find krakend/ -type f \( -name '*.json' -o -name '*.tmpl' \) \
  -exec sha256sum {} \; | sort | sha256sum | awk '{print $1}')
```
