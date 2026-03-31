# Config Validation Tools

## 1. KrakenD Check

Built-in validation command. Checks template syntax, JSON output validity, and KrakenD schema compliance.

```bash
docker run --rm \
  -v ./krakend:/etc/krakend \
  -e FC_ENABLE=1 \
  -e FC_SETTINGS=/etc/krakend/settings \
  -e FC_PARTIALS=/etc/krakend/partials \
  -e FC_TEMPLATES=/etc/krakend/templates \
  devopsfaith/krakend:2.7 \
  check -c /etc/krakend/krakend.tmpl
```

**Catches:** Template errors, invalid JSON, missing variables, schema violations.

## 2. Compile Config Script

`tools/compile-config.sh` — Compiles FC templates to static JSON. Used in the Dockerfile build stage.

```bash
bash tools/compile-config.sh
```

**Produces:** `/etc/krakend/krakend.json` (fully resolved, no templates)

## 3. Config Audit

`tools/config-audit/audit.sh` — Custom audit script with `--strict` mode.

```bash
bash tools/config-audit/audit.sh --strict
```

**Checks:**
- Environment consistency (same endpoints across dev/staging/prod)
- Security settings (JWT, CORS, rate limiting)
- CORS configuration validity
- Missing or inconsistent circuit breaker configs

## 4. OpenAPI Generator

`tools/openapi-generator/generate.py` — Generates OpenAPI spec from endpoint definitions.

```bash
pip install -r tools/openapi-generator/requirements.txt
python tools/openapi-generator/generate.py \
  --endpoints-dir krakend/endpoints \
  --output openapi.yaml
```

**Produces:** `openapi.yaml` with all gateway endpoints documented.

## 5. JSON Linting

Standard Python JSON validation for settings files:

```bash
python3 -m json.tool krakend/settings/dev.json > /dev/null
```

**Catches:** Syntax errors (missing commas, unmatched braces, trailing commas).

## 6. Config Hash

SHA256 hash of all KrakenD config files. Used as a deployment annotation to trigger rolling restarts when config changes.

```bash
HASH=$(find krakend/ -type f \( -name '*.json' -o -name '*.tmpl' \) \
  -exec sha256sum {} \; | sort | sha256sum | awk '{print $1}')
```

The hash is written to `deployment.yaml` as `checksum/config` annotation. When the hash changes, K8s triggers a rolling update.

## CI Pipeline

All validation tools run in CI (`.github/workflows/ci.yml`):

```
validate (krakend check + JSON lint)
    ├── config-audit (audit.sh --strict)
    ├── openapi-generate (generate.py)
    ├── docker-build (Dockerfile)
    └── config-hash (SHA256, main only)
```
