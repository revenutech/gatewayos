-- =============================================================================
-- Business Metrics Emitter
-- Enterprise KrakenD equivalent: telemetry/metrics (custom business metrics)
--
-- Tracks business-level metrics via Redis counters that Prometheus scrapes:
-- - Requests per tenant per endpoint
-- - Requests per subscription tier
-- - Auth method distribution (JWT vs API key)
-- - Error rates per tenant
-- - Revenue-impacting events (postings, settlements, payments)
--
-- Metrics are stored in Redis and exposed via a /metrics-business endpoint
-- or scraped by a sidecar exporter.
-- =============================================================================

function post_proxy(response)
    local redis_host = dynamic_config("redis_host") or "redis"
    local redis_port = tonumber(dynamic_config("redis_port") or "6379")

    local request = response:request()
    local status = response:statusCode()
    local tenant_id = request:headers("X-Tenant-ID") or "unknown"
    local tier = request:headers("X-RateLimit-Tier") or "default"
    local auth_method = request:headers("X-Auth-Method") or "jwt"
    local endpoint = request:url() or "unknown"
    local method = request:method() or "GET"

    -- Connect to Redis
    local ok, redis = pcall(function()
        local r = require("redis")
        return r.connect(redis_host, redis_port)
    end)

    if not ok or not redis then
        return
    end

    local now = os.time()
    local minute_key = math.floor(now / 60)

    -- 1. Requests per tenant (rolling 1h window)
    local tenant_key = string.format("metrics:tenant:%s:%d", tenant_id, minute_key)
    redis:call("INCR", tenant_key)
    redis:call("EXPIRE", tenant_key, 3600)

    -- 2. Requests per tier
    local tier_key = string.format("metrics:tier:%s:%d", tier, minute_key)
    redis:call("INCR", tier_key)
    redis:call("EXPIRE", tier_key, 3600)

    -- 3. Auth method counter
    local auth_key = string.format("metrics:auth:%s:%d", auth_method, minute_key)
    redis:call("INCR", auth_key)
    redis:call("EXPIRE", auth_key, 3600)

    -- 4. Error tracking per tenant (4xx and 5xx)
    if status >= 400 then
        local error_class = status >= 500 and "5xx" or "4xx"
        local err_key = string.format("metrics:errors:%s:%s:%d", tenant_id, error_class, minute_key)
        redis:call("INCR", err_key)
        redis:call("EXPIRE", err_key, 3600)
    end

    -- 5. Revenue events (specific endpoints that represent business transactions)
    local revenue_endpoints = {
        ["/v1/postings"] = "posting_created",
        ["/v1/settlements"] = "settlement_created",
        ["/v1/pix/"] = "pix_initiated",
        ["/v1/ted/"] = "ted_initiated",
        ["/v1/boleto/"] = "boleto_created"
    }

    if method == "POST" and status >= 200 and status < 300 then
        for pattern, event_name in pairs(revenue_endpoints) do
            if endpoint:find(pattern, 1, true) then
                local event_key = string.format("metrics:revenue:%s:%s:%d", tenant_id, event_name, minute_key)
                redis:call("INCR", event_key)
                redis:call("EXPIRE", event_key, 3600)

                -- Also increment total counter (never expires, for cumulative metrics)
                local total_key = string.format("metrics:revenue_total:%s:%s", tenant_id, event_name)
                redis:call("INCR", total_key)
                break
            end
        end
    end

    redis:call("QUIT")
end
