FROM krakend:2.13.4

# Fix CVEs - upgrade Alpine packages
# CVE-2026-22184 (zlib)
# CVE-2026-28390 (openssl)
# CVE-2026-40200 (musl)
RUN apk update && apk upgrade --no-cache zlib libcrypto3 libssl3 musl musl-utils && rm -rf /var/cache/apk/*

COPY krakend/ /etc/krakend/

ENV FC_ENABLE=1 \
    FC_SETTINGS=/etc/krakend/settings \
    FC_PARTIALS=/etc/krakend/partials \
    FC_TEMPLATES=/etc/krakend/templates \
    KRAKEND_PORT=8080 \
    USAGE_DISABLE=1

EXPOSE 8080 8090

HEALTHCHECK --interval=30s --timeout=3s --start-period=10s --retries=3 \
  CMD ["/usr/bin/wget", "--spider", "-q", "http://localhost:8080/__health"]

ENTRYPOINT ["krakend"]
CMD ["run", "-c", "/etc/krakend/krakend.tmpl"]
