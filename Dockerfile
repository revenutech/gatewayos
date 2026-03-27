# =============================================================================
# Revenu Platform — API Gateway Container Image
# Multi-stage: Python compiles FC templates → KrakenD runs static JSON
# ISO 27001: A.8.19 (Software installation), A.8.27 (Secure architecture)
# =============================================================================

# Stage 1: Compile Flexible Configuration templates to static JSON
FROM python:3.12-alpine AS compiler

COPY krakend/ /etc/krakend/
COPY tools/compile-config.sh /compile-config.sh

ENV KRAKEND_DIR=/etc/krakend \
    ENV=dev \
    OUTPUT=/etc/krakend/krakend.json

RUN chmod +x /compile-config.sh && sh /compile-config.sh

# Stage 2: Production runtime
FROM devopsfaith/krakend:2.7

# Copy compiled JSON config
COPY --from=compiler /etc/krakend/krakend.json /etc/krakend/krakend.json

# Copy Lua scripts needed at runtime
COPY krakend/partials/lua/ /etc/krakend/partials/lua/

# Disable FC at runtime — we use pre-compiled JSON
ENV FC_ENABLE=0 \
    KRAKEND_PORT=8080 \
    USAGE_DISABLE=1

EXPOSE 8080 8090

HEALTHCHECK --interval=30s --timeout=3s --start-period=10s --retries=3 \
  CMD ["/usr/bin/wget", "--spider", "-q", "http://localhost:8080/__health"]

ENTRYPOINT ["krakend"]
CMD ["run", "-c", "/etc/krakend/krakend.json"]
