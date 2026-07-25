#!/usr/bin/env bash
# =============================================================================
# KrakenD Config Audit Tool
# Enterprise KrakenD equivalent: developer/audit
#
# Detects configuration drift between environments, validates consistency,
# and ensures security policies are applied uniformly.
#
# Usage: ./audit.sh [--strict]
# Exit codes: 0 = pass, 1 = warnings found, 2 = errors found
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SETTINGS_DIR="${SCRIPT_DIR}/../../krakend/settings"
ENDPOINTS_DIR="${SCRIPT_DIR}/../../krakend/templates"
PARTIALS_DIR="${SCRIPT_DIR}/../../krakend/partials"
TEMPLATES_DIR="${SCRIPT_DIR}/../../krakend/templates"
STRICT="${1:-}"

ERRORS=0
WARNINGS=0

RED='\033[0;31m'
YELLOW='\033[0;33m'
GREEN='\033[0;32m'
NC='\033[0m'

error() { echo -e "${RED}[ERROR]${NC} $1"; ERRORS=$((ERRORS + 1)); }
warn()  { echo -e "${YELLOW}[WARN]${NC} $1"; WARNINGS=$((WARNINGS + 1)); }
pass()  { echo -e "${GREEN}[PASS]${NC} $1"; }

echo "========================================="
echo "KrakenD Config Audit"
echo "========================================="
echo ""

# ---- 1. Environment consistency ----
echo "--- Environment Consistency ---"

# Check all envs have same backend keys
DEV_BACKENDS=$(python3 -c "import json; d=json.load(open('${SETTINGS_DIR}/develop.json')); print(sorted(d.get('backends',{}).keys()))" 2>/dev/null || echo "PARSE_ERROR")
STG_BACKENDS=$(python3 -c "import json; d=json.load(open('${SETTINGS_DIR}/sandbox.json')); print(sorted(d.get('backends',{}).keys()))" 2>/dev/null || echo "PARSE_ERROR")
PRD_BACKENDS=$(python3 -c "import json; d=json.load(open('${SETTINGS_DIR}/production.json')); print(sorted(d.get('backends',{}).keys()))" 2>/dev/null || echo "PARSE_ERROR")

if [ "$DEV_BACKENDS" = "$STG_BACKENDS" ] && [ "$STG_BACKENDS" = "$PRD_BACKENDS" ]; then
    pass "Backend keys consistent across all environments"
else
    error "Backend keys differ between environments"
    echo "  develop:    $DEV_BACKENDS"
    echo "  sandbox:    $STG_BACKENDS"
    echo "  production: $PRD_BACKENDS"
fi

# Check all envs have same circuit breaker keys
for env in develop sandbox production; do
    CB_COUNT=$(python3 -c "
import json
d=json.load(open('${SETTINGS_DIR}/${env}.json'))
cbs = [k for k in d.keys() if k.startswith('cb_')]
print(len(cbs))
" 2>/dev/null || echo "0")
    echo "  ${env}: ${CB_COUNT} circuit breakers configured"
done

# ---- 2. Security audit ----
echo ""
echo "--- Security Audit ---"

# Check JWT validator has required fields
if grep -q "failed_jwk_key_cooldown" "${TEMPLATES_DIR}/jwt_validator.tmpl" 2>/dev/null; then
    pass "JWT validator has failed_jwk_key_cooldown"
else
    error "JWT validator missing failed_jwk_key_cooldown (key rotation risk)"
fi

if grep -q "roles_key_is_nested" "${TEMPLATES_DIR}/endpoint_ledger_v1.tmpl" 2>/dev/null; then
    pass "RBAC endpoints have roles_key_is_nested: true"
else
    error "Missing roles_key_is_nested in RBAC endpoints"
fi

# Check all protected endpoints have JWT validator
# Count both jwt_validator.tmpl template AND inline "auth/validator" config
TOTAL_ENDPOINTS=0
PROTECTED_ENDPOINTS=0
for f in "${ENDPOINTS_DIR}"/endpoint_*.tmpl; do
    [ -f "$f" ] || continue
    basename_f=$(basename "$f")
    # Skip intentionally public endpoints
    [ "$basename_f" = "endpoint_health.tmpl" ] && continue
    [ "$basename_f" = "endpoint_test_v1.tmpl" ] && continue
    [ "$basename_f" = "endpoint_docs_v1.tmpl" ] && continue
    [ "$basename_f" = "endpoint_keycloak_v1.tmpl" ] && continue
    [ "$basename_f" = "endpoint_paymentos_health_v1.tmpl" ] && continue

    count=$(grep -c '"endpoint"' "$f" 2>/dev/null || true)
    jwt_template=$(grep -c 'jwt_validator.tmpl' "$f" 2>/dev/null || true)
    auth_validator=$(grep -c '"auth/validator"' "$f" 2>/dev/null || true)
    count=${count:-0}
    jwt_template=${jwt_template:-0}
    auth_validator=${auth_validator:-0}
    # Count both methods of JWT protection
    jwt_count=$((jwt_template + auth_validator))
    TOTAL_ENDPOINTS=$((TOTAL_ENDPOINTS + count))
    PROTECTED_ENDPOINTS=$((PROTECTED_ENDPOINTS + jwt_count))
done
UNPROTECTED=$((TOTAL_ENDPOINTS - PROTECTED_ENDPOINTS))

# Endpoints publicos por design. Sem esta lista o indicador mede a coisa errada:
# conta como "desprotegido" o que e protegido por outro mecanismo (mTLS do BACEN,
# OIDC do Keycloak) ou o que e publico de proposito (health, docs, QR Pix).
INTENTIONAL_PUBLIC_PREFIXES="/__ready /__health /paymentos/jdpi /paymentos/banklink /auth/realms /pix/cob /v1/app/version"
# Publicos por natureza, em qualquer prefixo de modulo: emissao de token e documentacao
INTENTIONAL_PUBLIC_SUBSTRINGS="/oauth /docs /openapi"

# Exposicao publica se mede no que vai para PRODUCAO. Endpoint de teste em
# develop e legitimo; em producao e achado — coberto pela checagem seguinte.
# Compila sob demanda: no CI cada job e isolado, entao o audit nao pode
# depender de um arquivo deixado por outro job.
COMPILED="${PROD_COMPILED_CONFIG:-/tmp/krakend-prod.json}"
if [ ! -f "$COMPILED" ]; then
    bash "${SCRIPT_DIR}/../compile-config.sh" "${SCRIPT_DIR}/../../krakend" production "$COMPILED" >/dev/null 2>&1 || true
fi
if [ -f "$COMPILED" ]; then
    UNEXPECTED=$(COMPILED="$COMPILED" PREFIXES="$INTENTIONAL_PUBLIC_PREFIXES" SUBSTRINGS="$INTENTIONAL_PUBLIC_SUBSTRINGS" python3 - <<'PYEOF'
import json, os
cfg = json.load(open(os.environ["COMPILED"]))
prefixes = os.environ["PREFIXES"].split()
out = []
for e in cfg.get("endpoints", []):
    if "auth/validator" in json.dumps(e.get("extra_config", {})):
        continue
    path = e.get("endpoint", "")
    if any(path.startswith(p) for p in prefixes):
        continue
    if any(sub in path for sub in os.environ["SUBSTRINGS"].split()):
        continue
    if "health" in path or "live" in path or "ready" in path:
        continue
    out.append(f'{e.get("method","GET")} {path}')
print("\n".join(out))
PYEOF
)
    UNEXPECTED_COUNT=$(printf '%s' "$UNEXPECTED" | grep -c . || true)
    if [ "${UNEXPECTED_COUNT:-0}" -eq 0 ]; then
        pass "Producao: todo endpoint sem JWT esta na lista de publicos por design"
    else
        warn "Producao: ${UNEXPECTED_COUNT} endpoint(s) sem JWT e fora da lista de publicos por design:"
        printf '%s\n' "$UNEXPECTED" | sed 's/^/        /'
    fi
else
    warn "Config de producao ausente em ${COMPILED} — checagem de endpoint publico pulada"
fi

# Endpoint de teste nao deve existir em config de producao
PROD_COMPILED="$COMPILED"
if [ -f "$PROD_COMPILED" ]; then
    TEST_IN_PROD=$(PROD="$PROD_COMPILED" python3 -c "
import json, os
cfg = json.load(open(os.environ['PROD']))
print('\n'.join(e['endpoint'] for e in cfg.get('endpoints', []) if '/test/' in e.get('endpoint','')))
")
    TEST_COUNT=$(printf '%s' "$TEST_IN_PROD" | grep -c . || true)
    if [ "${TEST_COUNT:-0}" -eq 0 ]; then
        pass "Nenhum endpoint de teste no config de producao"
    else
        warn "${TEST_COUNT} endpoint(s) de teste presentes no config de PRODUCAO:"
        printf '%s\n' "$TEST_IN_PROD" | sed 's/^/        /'
    fi
fi

# Check bloom filter false positive rate
BF_P=$(grep -o '"P": [0-9.e-]*' "${TEMPLATES_DIR}/bloom_filter.tmpl" 2>/dev/null | grep -o '[0-9.e-]*' || echo "unknown")
if [ "$BF_P" != "unknown" ]; then
    # Python comparison for scientific notation
    GOOD=$(python3 -c "print('yes' if float('${BF_P}') <= 0.0001 else 'no')" 2>/dev/null || echo "unknown")
    if [ "$GOOD" = "yes" ]; then
        pass "Bloom filter FPR is low enough: ${BF_P}"
    else
        warn "Bloom filter FPR is high: ${BF_P} (recommend <= 0.0001)"
    fi
fi

# Check prod doesn't return error messages
PROD_ERROR_MSG=$(python3 -c "import json; d=json.load(open('${SETTINGS_DIR}/production.json')); print(d.get('service',{}).get('return_error_msg', False))" 2>/dev/null || echo "unknown")
if [ "$PROD_ERROR_MSG" = "False" ]; then
    pass "Prod does not expose error messages"
else
    error "Prod exposes error messages (return_error_msg: true)"
fi

# ---- 3. CORS audit ----
echo ""
echo "--- CORS Audit ---"

for env in develop sandbox production; do
    ORIGINS=$(python3 -c "
import json
d=json.load(open('${SETTINGS_DIR}/${env}.json'))
print(d.get('cors',{}).get('allow_origins', []))
" 2>/dev/null || echo "[]")

    if echo "$ORIGINS" | grep -q '\*'; then
        error "${env}: CORS allows wildcard origin (*)"
    else
        pass "${env}: CORS origins restricted: ${ORIGINS}"
    fi
done

# ---- 4. Rate limiting audit ----
echo ""
echo "--- Rate Limiting Audit ---"

for env in develop sandbox production; do
    RL=$(python3 -c "
import json
d=json.load(open('${SETTINGS_DIR}/${env}.json'))
rl=d.get('rate_limit',{})
print(f\"global={rl.get('global_max','N/A')} tenant={rl.get('tenant_max','N/A')}\")
" 2>/dev/null || echo "N/A")
    echo "  ${env}: ${RL}"
done

# ---- 5. JSON validity ----
echo ""
echo "--- JSON Validity ---"

for f in "${SETTINGS_DIR}"/*.json; do
    if python3 -m json.tool "$f" > /dev/null 2>&1; then
        pass "Valid: $(basename "$f")"
    else
        error "Invalid JSON: $(basename "$f")"
    fi
done

# ---- Summary ----
echo ""
echo "========================================="
echo "Audit Summary: ${ERRORS} errors, ${WARNINGS} warnings"
echo "========================================="

if [ "$ERRORS" -gt 0 ]; then
    exit 2
elif [ "$WARNINGS" -gt 0 ] && [ "$STRICT" = "--strict" ]; then
    exit 1
else
    exit 0
fi
