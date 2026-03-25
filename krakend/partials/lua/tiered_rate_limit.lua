-- =============================================================================
-- Tiered Rate Limiting
-- Enterprise KrakenD equivalent: qos/ratelimit/tiered
--
-- Applies different rate limits based on the client's subscription tier.
-- Tier is extracted from JWT claim (propagated as X-Rate-Limit-Tier header)
-- or from the API key metadata.
--
-- Tiers:
--   free       — lowest limits (trial/free plan)
--   starter    — basic paid plan
--   pro        — professional plan
--   enterprise — highest limits (custom SLA)
--
-- Falls back to "free" tier if no tier is detected.
-- Uses Redis sliding window (same pattern as redis_rate_limit.lua).
-- =============================================================================

-- Tier definitions: { max_rate_per_minute, burst }
local TIERS = {
    free       = { rate = 60,    burst = 10  },
    starter    = { rate = 300,   burst = 50  },
    pro        = { rate = 1000,  burst = 200 },
    enterprise = { rate = 5000,  burst = 1000 }
}

-- Default tier when none is detected
local DEFAULT_TIER = "free"

function pre_proxy(request)
    local redis_host = dynamic_config("redis_host") or "redis"
    local redis_port = tonumber(dynamic_config("redis_port") or "6379")
    local window = 60  -- 1 minute window

    -- Determine tier from headers (set by JWT propagation or API key plugin)
    local tier = request:headers("X-Rate-Limit-Tier")
    if not tier or tier == "" then
        -- Try to extract from JWT subscription_tier claim (propagated header)
        tier = request:headers("X-Subscription-Tier")
    end
    if not tier or tier == "" or not TIERS[tier] then
        tier = DEFAULT_TIER
    end

    local tier_config = TIERS[tier]
    local tenant_id = request:headers("X-Tenant-ID") or "unknown"
    local endpoint = request:url()
    local now = os.time()
    local window_key = math.floor(now / window)

    -- Rate limit key: per-tenant, per-tier, per-endpoint, per-window
    local key = string.format("rl:tiered:%s:%s:%s:%d", tier, tenant_id, endpoint, window_key)

    -- Connect to Redis
    local ok, redis = pcall(function()
        local r = require("redis")
        return r.connect(redis_host, redis_port)
    end)

    -- Fail-open
    if not ok or not redis then
        request:headers("X-RateLimit-Tier", tier)
        request:headers("X-RateLimit-Fallback", "local")
        return
    end

    -- Check current count
    local count = tonumber(redis:call("GET", key) or "0")
    local max_rate = tier_config.rate

    if count >= max_rate then
        redis:call("QUIT")
        local reset_at = (window_key + 1) * window
        local retry_after = reset_at - now

        local response = request:response()
        response:statusCode(429)
        response:headers("Content-Type", "application/json")
        response:headers("X-RateLimit-Limit", tostring(max_rate))
        response:headers("X-RateLimit-Remaining", "0")
        response:headers("X-RateLimit-Reset", tostring(reset_at))
        response:headers("X-RateLimit-Tier", tier)
        response:headers("Retry-After", tostring(retry_after))
        response:body('{"error":"rate_limit_exceeded","message":"Rate limit exceeded for tier: ' .. tier .. '","tier":"' .. tier .. '","limit":' .. tostring(max_rate) .. ',"retry_after":' .. tostring(retry_after) .. '}')
        return
    end

    -- Increment counter
    redis:call("MULTI")
    redis:call("INCR", key)
    redis:call("EXPIRE", key, window * 2)
    redis:call("EXEC")

    -- Set response headers
    request:headers("X-RateLimit-Limit", tostring(max_rate))
    request:headers("X-RateLimit-Remaining", tostring(max_rate - count - 1))
    request:headers("X-RateLimit-Reset", tostring((window_key + 1) * window))
    request:headers("X-RateLimit-Tier", tier)

    redis:call("QUIT")
end
