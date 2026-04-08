# Troubleshooting

## Config Validation Errors

**Symptom:** `krakend check` fails

**Solutions:**
- Check JSON syntax in settings files: `python3 -m json.tool krakend/settings/dev.json`
- Verify all template variables exist in settings (missing var = empty string = invalid JSON)
- Check that endpoint files are valid JSON (ignoring Go template syntax)
- Run `tools/config-audit/audit.sh` for detailed diagnostics

## JWT Validation Failures (401)

**Symptom:** All authenticated requests return 401

**Check:**
- Is Keycloak reachable from the gateway? (Network policy allows egress to Keycloak on 8443/8080)
- Is the JWKS URL correct for the environment? (dev vs staging vs prod)
- Is the token expired? Check `exp` claim
- Does the token audience match `revenu-platform`?
- Does the token issuer match the configured issuer?
- Is the JWKS cache stale? Wait for cache_duration (3600s) or restart gateway

## RBAC Failures (403)

**Symptom:** Authenticated user gets 403

**Check:**
- Does the user's JWT contain the required role in `realm_access.roles`?
- Is the endpoint configured with `roles_key_is_nested: true`?
- Review the [RBAC matrix](../security/rbac-matrix.md)

## Circuit Breaker Open (503)

**Symptom:** Requests to a specific backend return 503

**Check:**
- Which CB is open? Check logs for `circuit breaker {name} changed to OPEN`
- Is the backend healthy? Check backend pod status
- Check Prometheus: `krakend_circuit_breaker_open`
- Wait for timeout period (5-30s depending on backend)

## Rate Limiting (429)

**Symptom:** Requests return 429 Too Many Requests

**Check:**
- Is `X-Tenant-ID` header present? (Rate limiting keys on this header)
- What are the limits for this endpoint? See [rate-limiting.md](../security/rate-limiting.md)
- Are multiple gateway instances sharing state? (Native rate limiter is per-instance)

## gRPC Transcoder Errors

**Symptom:** `/grpc/v1/*` endpoints fail

**Check:**
- Is Envoy sidecar running? `curl http://localhost:9901/ready`
- Is the proto descriptor up to date? Check `envoy/proto/ledgeros.pb`
- Is LedgerOS gRPC port (9081) accessible?
- Check Envoy logs: `docker compose logs envoy-grpc-transcoder`

## 502 Bad Gateway

**Symptom:** Intermittent 502 errors

**Check:**
- Backend is unreachable (wrong host/port in settings)
- Network policy blocking egress
- Backend pod is restarting
- DNS resolution failure

## 504 Gateway Timeout

**Symptom:** Slow requests return 504

**Check:**
- Default timeout is 3000ms. Is the backend responding within this?
- Dashboard endpoints have 5000ms timeout
- Check backend latency in Prometheus
- Consider increasing timeout for specific endpoints

## CORS Errors

**Symptom:** Browser console shows CORS errors

**Check:**
- Is the request origin in `cors.allow_origins` for the current environment?
- Dev allows `localhost:3000` and `localhost:8081`
- Staging allows `staging.revenu.com.br`
- Prod allows `app.revenu.com.br`
- Is the request using an allowed method?
- Is the `Authorization` header in `allow_headers`?
