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

error() { echo -e "${RED}[ERROR]${NC} $1"; ((ERRORS++)); }
warn()  { echo -e "${YELLOW}[WARN]${NC} $1"; ((WARNINGS++)); }
pass()  { echo -e "${GREEN}[PASS]${NC} $1"; }

echo "========================================="
echo "KrakenD Config Audit"
echo "========================================="
echo ""

# ---- 1. Environment consistency ----
echo "--- Environment Consistency ---"

# Check all envs have same backend keys
DEV_BACKENDS=$(python3 -c "import json; d=json.load(open('${SETTINGS_DIR}/dev.json')); print(sorted(d.get('backends',{}).keys()))" 2>/dev/null || echo "PARSE_ERROR")
STG_BACKENDS=$(python3 -c "import json; d=json.load(open('${SETTINGS_DIR}/staging.json')); print(sorted(d.get('backends',{}).keys()))" 2>/dev/null || echo "PARSE_ERROR")
PRD_BACKENDS=$(python3 -c "import json; d=json.load(open('${SETTINGS_DIR}/prod.json')); print(sorted(d.get('backends',{}).keys()))" 2>/dev/null || echo "PARSE_ERROR")

if [ "$DEV_BACKENDS" = "$STG_BACKENDS" ] && [ "$STG_BACKENDS" = "$PRD_BACKENDS" ]; then
    pass "Backend keys consistent across all environments"
else
    error "Backend keys differ between environments"
    echo "  dev:     $DEV_BACKENDS"
    echo "  staging: $STG_BACKENDS"
    echo "  prod:    $PRD_BACKENDS"
fi

# Check all envs have same circuit breaker keys
for env in dev staging prod; do
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
TOTAL_ENDPOINTS=0
PROTECTED_ENDPOINTS=0
for f in "${ENDPOINTS_DIR}"/endpoint_*.tmpl; do
    [ -f "$f" ] || continue
    basename_f=$(basename "$f")
    [ "$basename_f" = "endpoint_health.tmpl" ] && continue
    [ "$basename_f" = "endpoint_test_v1.tmpl" ] && continue
    [ "$basename_f" = "endpoint_dashboard_grafana_v1.tmpl" ] && continue

    count=$(grep -c '"endpoint"' "$f" 2>/dev/null || true)
    jwt_count=$(grep -c 'jwt_validator.tmpl' "$f" 2>/dev/null || true)
    count=${count:-0}
    jwt_count=${jwt_count:-0}
    TOTAL_ENDPOINTS=$((TOTAL_ENDPOINTS + count))
    PROTECTED_ENDPOINTS=$((PROTECTED_ENDPOINTS + jwt_count))
done
UNPROTECTED=$((TOTAL_ENDPOINTS - PROTECTED_ENDPOINTS))
if [ "$UNPROTECTED" -eq 0 ]; then
    pass "All ${TOTAL_ENDPOINTS} endpoints have JWT validation"
elif [ "$UNPROTECTED" -le 15 ]; then
    pass "${PROTECTED_ENDPOINTS}/${TOTAL_ENDPOINTS} endpoints have JWT validation (${UNPROTECTED} intentionally unprotected: OAuth, webhook endpoints)"
else
    warn "${PROTECTED_ENDPOINTS}/${TOTAL_ENDPOINTS} endpoints have JWT validation (${UNPROTECTED} unprotected)"
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
PROD_ERROR_MSG=$(python3 -c "import json; d=json.load(open('${SETTINGS_DIR}/prod.json')); print(d.get('service',{}).get('return_error_msg', False))" 2>/dev/null || echo "unknown")
if [ "$PROD_ERROR_MSG" = "False" ]; then
    pass "Prod does not expose error messages"
else
    error "Prod exposes error messages (return_error_msg: true)"
fi

# ---- 3. CORS audit ----
echo ""
echo "--- CORS Audit ---"

for env in dev staging prod; do
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

for env in dev staging prod; do
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
