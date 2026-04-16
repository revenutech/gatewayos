#!/bin/sh
# =============================================================================
# KrakenD CE 2.9.4 — Dependency Patch Script
# Patches go-jose v3/v4 to fix CVE-2026-34986 (JWE decryption panic)
# ISO 27001: A.8.8 (Management of technical vulnerabilities)
#
# This script clones KrakenD CE 2.9.4, applies go.mod replace directives
# for patched dependencies, and builds a custom binary.
# =============================================================================
set -e

KRAKEND_VERSION="2.9.4"
REPO_URL="https://github.com/krakend/krakend-ce.git"
WORKDIR="/build/krakend-ce"

echo "==> Cloning KrakenD CE v${KRAKEND_VERSION}..."
git clone --depth 1 --branch "v${KRAKEND_VERSION}" "${REPO_URL}" "${WORKDIR}"
cd "${WORKDIR}"

echo "==> Patching go-jose v3.0.4 → v3.0.5 (CVE-2026-34986)..."
go mod edit -replace=github.com/go-jose/go-jose/v3=github.com/go-jose/go-jose/v3@v3.0.5

echo "==> Patching go-jose v4.0.5 → v4.1.4 (CVE-2026-34986)..."
go mod edit -replace=github.com/go-jose/go-jose/v4=github.com/go-jose/go-jose/v4@v4.1.4

echo "==> Running go mod tidy..."
go mod tidy

echo "==> Building KrakenD binary..."
go build \
  -ldflags="-X github.com/krakendio/krakend-ce/v2/pkg.Version=${KRAKEND_VERSION}-patched \
            -X github.com/luraproject/lura/v2/core.KrakendVersion=${KRAKEND_VERSION}-patched" \
  -o /build/krakend \
  ./cmd/krakend-ce

echo "==> Build complete: /build/krakend"
/build/krakend version
