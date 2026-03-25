-- =============================================================================
-- Custom HTTP Circuit Breaker
-- Enterprise KrakenD equivalent: qos/circuit-breaker/http (custom status codes)
--
-- Enhances KrakenD CE's built-in circuit breaker with:
-- - Custom status code classification (only 5xx opens the CB, not 4xx)
-- - Per-backend error tracking via Redis (shared across instances)
-- - Configurable degraded response when circuit is open
-- - Half-open state with gradual recovery
--
-- States:
--   CLOSED  — normal operation, tracking errors
--   OPEN    — circuit tripped, returning fallback response
--   HALF    — testing recovery, allowing limited requests through
-- =============================================================================

-- Circuit state constants
local STATE_CLOSED  = "closed"
local STATE_OPEN    = "open"
local STATE_HALF    = "half_open"

-- Status codes that count as errors (only server errors)
local ERROR_STATUS_CODES = {
    [500] = true, [502] = true, [503] = true, [504] = true
}

-- Status codes that are NOT errors (client errors are expected)
-- 400, 401, 403, 404, 409, 422 etc. do NOT trip the circuit breaker

function post_proxy(response)
    local redis_host = dynamic_config("redis_host") or "redis"
    local redis_port = tonumber(dynamic_config("redis_port") or "6379")
    local backend_name = dynamic_config("backend_name") or "default"
    local max_errors = tonumber(dynamic_config("max_errors") or "5")
    local interval = tonumber(dynamic_config("interval") or "60")
    local recovery_time = tonumber(dynamic_config("recovery_time") or "30")
    local half_open_max = tonumber(dynamic_config("half_open_max") or "3")

    local status_code = response:statusCode()
    local now = os.time()

    -- Connect to Redis
    local ok, redis = pcall(function()
        local r = require("redis")
        return r.connect(redis_host, redis_port)
    end)

    -- Fail-open: if Redis unavailable, rely on built-in CB
    if not ok or not redis then
        return
    end

    local state_key = string.format("cb:%s:state", backend_name)
    local errors_key = string.format("cb:%s:errors", backend_name)
    local opened_key = string.format("cb:%s:opened_at", backend_name)
    local half_key = string.format("cb:%s:half_open_count", backend_name)

    -- Get current circuit state
    local current_state = redis:call("GET", state_key) or STATE_CLOSED

    -- Track server errors only
    if ERROR_STATUS_CODES[status_code] then
        -- Increment error counter
        redis:call("INCR", errors_key)
        redis:call("EXPIRE", errors_key, interval)

        local error_count = tonumber(redis:call("GET", errors_key) or "0")

        -- Check if threshold exceeded
        if error_count >= max_errors and current_state == STATE_CLOSED then
            -- Trip the circuit
            redis:call("SET", state_key, STATE_OPEN)
            redis:call("EXPIRE", state_key, recovery_time * 2)
            redis:call("SET", opened_key, tostring(now))
            redis:call("EXPIRE", opened_key, recovery_time * 2)

            -- Add circuit breaker headers
            response:headers("X-Circuit-Breaker", backend_name)
            response:headers("X-Circuit-State", STATE_OPEN)
        end
    else
        -- Successful response in half-open state -> close the circuit
        if current_state == STATE_HALF then
            local half_count = tonumber(redis:call("INCR", half_key) or "0")
            redis:call("EXPIRE", half_key, recovery_time)

            if half_count >= half_open_max then
                -- Enough successes in half-open -> close circuit
                redis:call("SET", state_key, STATE_CLOSED)
                redis:call("DEL", errors_key)
                redis:call("DEL", half_key)
                redis:call("DEL", opened_key)
                response:headers("X-Circuit-State", STATE_CLOSED)
            end
        end
    end

    -- Set circuit state header for observability
    response:headers("X-Circuit-Breaker-Backend", backend_name)
    response:headers("X-Circuit-Breaker-State", current_state)

    redis:call("QUIT")
end

-- Pre-proxy check: if circuit is OPEN, return degraded response
function pre_proxy(request)
    local redis_host = dynamic_config("redis_host") or "redis"
    local redis_port = tonumber(dynamic_config("redis_port") or "6379")
    local backend_name = dynamic_config("backend_name") or "default"
    local recovery_time = tonumber(dynamic_config("recovery_time") or "30")

    -- Connect to Redis
    local ok, redis = pcall(function()
        local r = require("redis")
        return r.connect(redis_host, redis_port)
    end)

    if not ok or not redis then
        return
    end

    local state_key = string.format("cb:%s:state", backend_name)
    local opened_key = string.format("cb:%s:opened_at", backend_name)
    local current_state = redis:call("GET", state_key) or STATE_CLOSED

    if current_state == STATE_OPEN then
        -- Check if recovery time has elapsed -> transition to half-open
        local opened_at = tonumber(redis:call("GET", opened_key) or "0")
        local now = os.time()

        if (now - opened_at) >= recovery_time then
            -- Transition to half-open (allow limited traffic through)
            redis:call("SET", state_key, STATE_HALF)
            redis:call("EXPIRE", state_key, recovery_time * 2)
            redis:call("QUIT")
            -- Allow this request through as part of half-open test
            request:headers("X-Circuit-Breaker-State", STATE_HALF)
            return
        end

        -- Circuit is open -> return degraded response
        redis:call("QUIT")
        local retry_after = recovery_time - (now - opened_at)

        local response = request:response()
        response:statusCode(503)
        response:headers("Content-Type", "application/json")
        response:headers("X-Circuit-Breaker", backend_name)
        response:headers("X-Circuit-Breaker-State", STATE_OPEN)
        response:headers("Retry-After", tostring(retry_after))
        response:body('{"error":"service_unavailable","message":"Service temporarily unavailable (circuit breaker open)","backend":"' .. backend_name .. '","retry_after":' .. tostring(retry_after) .. '}')
        return
    end

    redis:call("QUIT")
    request:headers("X-Circuit-Breaker-State", current_state)
end
