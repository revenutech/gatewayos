-- =============================================================================
-- Structured Access Log
-- Enterprise KrakenD equivalent: telemetry/logging (custom access log)
--
-- Emits structured JSON access logs with business context fields:
-- - tenant_id, user_id, auth_method
-- - endpoint, method, status_code, latency_ms
-- - rate_limit_tier, circuit_breaker_state
-- - geo_country, correlation_id
--
-- Logs are written to stdout (captured by K8s log collector).
-- =============================================================================

function post_proxy(response)
    local request = response:request()

    local now = os.time()
    local status = response:statusCode()

    -- Extract context from headers
    local tenant_id = request:headers("X-Tenant-ID") or ""
    local user_id = request:headers("X-User-ID") or ""
    local correlation_id = request:headers("X-Correlation-ID") or ""
    local auth_method = request:headers("X-Auth-Method") or "jwt"
    local tier = request:headers("X-RateLimit-Tier") or "default"
    local cb_state = response:headers("X-Circuit-Breaker-State") or "n/a"
    local geo_country = request:headers("X-Geo-Country") or ""
    local endpoint = request:url() or ""
    local method = request:method() or ""
    local api_key_id = request:headers("X-API-Key-ID") or ""

    -- Build structured log entry
    local log_entry = string.format(
        '{"@timestamp":"%s","level":"access","tenant_id":"%s","user_id":"%s",' ..
        '"correlation_id":"%s","auth_method":"%s","api_key_id":"%s",' ..
        '"endpoint":"%s","method":"%s","status":%d,' ..
        '"tier":"%s","cb_state":"%s","geo_country":"%s",' ..
        '"component":"krakend-gateway"}',
        os.date("!%Y-%m-%dT%H:%M:%SZ", now),
        tenant_id, user_id,
        correlation_id, auth_method, api_key_id,
        endpoint, method, status,
        tier, cb_state, geo_country
    )

    -- Print to stdout (captured by K8s logging)
    print(log_entry)
end
