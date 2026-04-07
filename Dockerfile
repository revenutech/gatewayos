# =============================================================================
# Revenu Platform — API Gateway Container Image
# Multi-stage build:
#   Stage 1: Build patched KrakenD binary (CVE-2026-34986 fix)
#   Stage 2: Compile FC templates to static JSON
#   Stage 3: Production runtime (Alpine)
# ISO 27001: A.8.8 (Vulnerability management), A.8.19 (Software installation)
# =============================================================================

# Stage 1: Build KrakenD CE 2.9.4 with patched go-jose
FROM golang:1.24.2-alpine3.21 AS krakend-builder

RUN apk add --no-cache make gcc musl-dev git

COPY build/krakend/patch-deps.sh /build/patch-deps.sh
RUN chmod +x /build/patch-deps.sh && /build/patch-deps.sh

# Stage 2: Compile Flexible Configuration templates to static JSON
FROM python:3.12-alpine AS compiler

COPY krakend/ /etc/krakend/
COPY tools/compile-config.sh /compile-config.sh

ENV KRAKEND_DIR=/etc/krakend \
    ENV=dev \
    OUTPUT=/etc/krakend/krakend.json

RUN chmod +x /compile-config.sh && sh /compile-config.sh

# Stage 3: Production runtime
FROM alpine:3.21

RUN apk upgrade --no-cache && \
    apk add --no-cache ca-certificates tzdata && \
    adduser -u 1000 -D -h /home/krakend krakend

# Copy patched KrakenD binary
COPY --from=krakend-builder /build/krakend /usr/bin/krakend

# Copy compiled JSON config
COPY --from=compiler /etc/krakend/krakend.json /etc/krakend/krakend.json

# Copy Lua scripts needed at runtime
COPY krakend/partials/lua/ /etc/krakend/partials/lua/

# Disable FC at runtime — we use pre-compiled JSON
ENV FC_ENABLE=0 \
    KRAKEND_PORT=8080 \
    USAGE_DISABLE=1

EXPOSE 8080 8090

USER 1000

HEALTHCHECK --interval=30s --timeout=3s --start-period=10s --retries=3 \
  CMD ["/usr/bin/wget", "--spider", "-q", "http://localhost:8080/__health"]

ENTRYPOINT ["krakend"]
CMD ["run", "-c", "/etc/krakend/krakend.json"]
