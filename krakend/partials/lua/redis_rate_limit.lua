-- =============================================================================
-- Redis-backed Distributed Rate Limiter
-- Enterprise KrakenD equivalent: qos/ratelimit/service (Redis-backed)
--
-- Uses sliding window counter pattern with Redis MULTI/EXEC.
-- Falls back to allowing requests if Redis is unavailable (fail-open).
--
-- Expected headers from JWT propagation:
--   X-Tenant-ID: tenant identifier for per-tenant limits
--
-- Configuration via extra_config "modifier/lua-proxy":
--   redis_host, redis_port, global_max, tenant_max, window_seconds
-- =============================================================================

function pre_proxy(request)
    local redis_host = dynamic_config("redis_host") or "redis"
    local redis_port = tonumber(dynamic_config("redis_port") or "6379")
    local global_max = tonumber(dynamic_config("global_max") or "10000")
    local tenant_max = tonumber(dynamic_config("tenant_max") or "1000")
    local window = tonumber(dynamic_config("window_seconds") or "60")

    local tenant_id = request:headers("X-Tenant-ID")
    local endpoint = request:url()
    local now = os.time()
    local window_key = math.floor(now / window)

    -- Global rate limit key
    local global_key = string.format("rl:global:%s:%d", endpoint, window_key)

    -- Per-tenant rate limit key
    local tenant_key = nil
    if tenant_id and tenant_id ~= "" then
        tenant_key = string.format("rl:tenant:%s:%s:%d", tenant_id, endpoint, window_key)
    end

    -- Connect to Redis
    local ok, redis = pcall(function()
        local r = require("redis")
        return r.connect(redis_host, redis_port)
    end)

    -- Fail-open: if Redis is unavailable, allow the request
    if not ok or not redis then
        request:headers("X-RateLimit-Fallback", "local")
        return
    end

    -- Check global rate limit
    local global_count = tonumber(redis:call("GET", global_key) or "0")
    if global_count >= global_max then
        redis:call("QUIT")
        local response = request:response()
        response:statusCode(429)
        response:headers("Content-Type", "application/json")
        response:headers("X-RateLimit-Limit", tostring(global_max))
        response:headers("X-RateLimit-Remaining", "0")
        response:headers("X-RateLimit-Reset", tostring((window_key + 1) * window))
        response:headers("Retry-After", tostring(((window_key + 1) * window) - now))
        response:body('{"error":"rate_limit_exceeded","message":"Global rate limit exceeded","retry_after":' .. tostring(((window_key + 1) * window) - now) .. '}')
        return
    end

    -- Check per-tenant rate limit
    if tenant_key then
        local tenant_count = tonumber(redis:call("GET", tenant_key) or "0")
        if tenant_count >= tenant_max then
            redis:call("QUIT")
            local response = request:response()
            response:statusCode(429)
            response:headers("Content-Type", "application/json")
            response:headers("X-RateLimit-Limit", tostring(tenant_max))
            response:headers("X-RateLimit-Remaining", "0")
            response:headers("X-RateLimit-Reset", tostring((window_key + 1) * window))
            response:headers("X-RateLimit-Scope", "tenant")
            response:headers("Retry-After", tostring(((window_key + 1) * window) - now))
            response:body('{"error":"rate_limit_exceeded","message":"Tenant rate limit exceeded","tenant_id":"' .. tenant_id .. '","retry_after":' .. tostring(((window_key + 1) * window) - now) .. '}')
            return
        end
    end

    -- Increment counters atomically
    redis:call("MULTI")
    redis:call("INCR", global_key)
    redis:call("EXPIRE", global_key, window * 2)
    if tenant_key then
        redis:call("INCR", tenant_key)
        redis:call("EXPIRE", tenant_key, window * 2)
    end
    redis:call("EXEC")

    -- Set rate limit response headers
    request:headers("X-RateLimit-Limit-Global", tostring(global_max))
    request:headers("X-RateLimit-Remaining-Global", tostring(global_max - global_count - 1))
    if tenant_key then
        local tenant_count = tonumber(redis:call("GET", tenant_key) or "0")
        request:headers("X-RateLimit-Limit-Tenant", tostring(tenant_max))
        request:headers("X-RateLimit-Remaining-Tenant", tostring(tenant_max - tenant_count))
    end

    redis:call("QUIT")
end
