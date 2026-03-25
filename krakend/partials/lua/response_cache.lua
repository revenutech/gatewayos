-- =============================================================================
-- Redis Response Cache
-- Enterprise KrakenD equivalent: backend/http-cache (shared Redis cache)
--
-- Caches backend responses in Redis for configurable TTL.
-- Cache key includes: endpoint + method + tenant_id + query params.
-- Only caches GET requests with 200 status.
-- Respects Cache-Control: no-cache from clients.
--
-- Cache invalidation:
-- - TTL-based automatic expiration
-- - Manual: redis-cli DEL "cache:..."
-- - Per-tenant: redis-cli KEYS "cache:*:tenant_id:*" | xargs redis-cli DEL
-- =============================================================================

local DEFAULT_TTL = 60  -- 1 minute default cache TTL

function pre_proxy(request)
    local method = request:method()

    -- Only cache GET requests
    if method ~= "GET" then
        return
    end

    -- Respect Cache-Control: no-cache
    local cache_control = request:headers("Cache-Control") or ""
    if cache_control:find("no-cache") or cache_control:find("no-store") then
        request:headers("X-Cache", "BYPASS")
        return
    end

    local redis_host = dynamic_config("redis_host") or "redis"
    local redis_port = tonumber(dynamic_config("redis_port") or "6379")

    local tenant_id = request:headers("X-Tenant-ID") or "global"
    local endpoint = request:url() or ""

    -- Build cache key
    local cache_key = string.format("cache:%s:%s", tenant_id, endpoint)

    -- Connect to Redis
    local ok, redis = pcall(function()
        local r = require("redis")
        return r.connect(redis_host, redis_port)
    end)

    if not ok or not redis then
        request:headers("X-Cache", "MISS-REDIS-DOWN")
        return
    end

    -- Check cache
    local cached = redis:call("GET", cache_key)
    if cached and cached ~= "" then
        redis:call("QUIT")
        -- Cache hit — return cached response
        local response = request:response()
        response:statusCode(200)
        response:headers("Content-Type", "application/json")
        response:headers("X-Cache", "HIT")
        response:headers("X-Cache-Key", cache_key)
        response:body(cached)
        return
    end

    redis:call("QUIT")
    -- Cache miss — request will proceed to backend
    request:headers("X-Cache", "MISS")
    request:headers("X-Cache-Key", cache_key)
end

function post_proxy(response)
    local status = response:statusCode()

    -- Only cache successful GET responses
    if status ~= 200 then
        return
    end

    local request = response:request()
    local cache_key = request:headers("X-Cache-Key")
    local cache_status = request:headers("X-Cache")

    -- Don't re-cache cache hits or bypasses
    if not cache_key or cache_key == "" or cache_status == "HIT" or cache_status == "BYPASS" then
        return
    end

    local redis_host = dynamic_config("redis_host") or "redis"
    local redis_port = tonumber(dynamic_config("redis_port") or "6379")
    local ttl = tonumber(dynamic_config("cache_ttl") or tostring(DEFAULT_TTL))

    local ok, redis = pcall(function()
        local r = require("redis")
        return r.connect(redis_host, redis_port)
    end)

    if not ok or not redis then
        return
    end

    -- Cache the response body
    local body = response:body()
    if body and body ~= "" then
        redis:call("SETEX", cache_key, ttl, body)
    end

    redis:call("QUIT")

    -- Set cache headers
    response:headers("X-Cache", "MISS")
    response:headers("X-Cache-TTL", tostring(ttl))
end
