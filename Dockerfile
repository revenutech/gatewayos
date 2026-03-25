FROM devopsfaith/krakend:2.7

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
