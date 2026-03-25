-- =============================================================================
-- Token Revocation via Redis
-- Enterprise KrakenD equivalent: auth/revoker (Revoke Server)
--
-- Provides cluster-wide token revocation using Redis as a shared store.
-- Replaces the built-in bloom filter RPC sync (port 1234) with Redis
-- for reliable cross-instance revocation.
--
-- Flow:
-- 1. Revocation service writes revoked JTI to Redis SET "revoked_tokens"
-- 2. Each KrakenD instance checks this SET on every request
-- 3. Redis TTL auto-cleans expired revocations (matches token TTL)
--
-- To revoke a token:
--   redis-cli SADD revoked_tokens "<jti>"
--   redis-cli EXPIRE revoked_tokens 3600
--
-- Or via the revocation API endpoint (see admin endpoints).
-- =============================================================================

function pre_proxy(request)
    local redis_host = dynamic_config("redis_host") or "redis"
    local redis_port = tonumber(dynamic_config("redis_port") or "6379")

    -- Extract JTI from the propagated JWT claims
    -- KrakenD propagates JTI via a custom claim mapping
    local jti = request:headers("X-JWT-JTI")

    -- No JTI available — skip revocation check
    if not jti or jti == "" then
        return
    end

    -- Connect to Redis
    local ok, redis = pcall(function()
        local r = require("redis")
        return r.connect(redis_host, redis_port)
    end)

    -- Fail-open: if Redis is unavailable, allow the request
    -- The built-in bloom filter still provides local revocation
    if not ok or not redis then
        request:headers("X-Revocation-Check", "skipped-redis-unavailable")
        return
    end

    -- Check if token JTI is in the revoked set
    local is_revoked = redis:call("SISMEMBER", "revoked_tokens", jti)

    if is_revoked and tonumber(is_revoked) == 1 then
        redis:call("QUIT")
        local response = request:response()
        response:statusCode(401)
        response:headers("Content-Type", "application/json")
        response:headers("WWW-Authenticate", "Bearer error=\"invalid_token\", error_description=\"Token has been revoked\"")
        response:body('{"error":"token_revoked","message":"This token has been revoked","jti":"' .. jti .. '"}')
        return
    end

    -- Also check per-user revocation (revoke all tokens for a user)
    local user_id = request:headers("X-User-ID")
    if user_id and user_id ~= "" then
        local user_revoked = redis:call("SISMEMBER", "revoked_users", user_id)
        if user_revoked and tonumber(user_revoked) == 1 then
            redis:call("QUIT")
            local response = request:response()
            response:statusCode(401)
            response:headers("Content-Type", "application/json")
            response:headers("WWW-Authenticate", "Bearer error=\"invalid_token\", error_description=\"All tokens for this user have been revoked\"")
            response:body('{"error":"user_tokens_revoked","message":"All tokens for this user have been revoked"}')
            return
        end
    end

    -- Also check per-tenant revocation (emergency: revoke all tokens for a tenant)
    local tenant_id = request:headers("X-Tenant-ID")
    if tenant_id and tenant_id ~= "" then
        local tenant_revoked = redis:call("SISMEMBER", "revoked_tenants", tenant_id)
        if tenant_revoked and tonumber(tenant_revoked) == 1 then
            redis:call("QUIT")
            local response = request:response()
            response:statusCode(401)
            response:headers("Content-Type", "application/json")
            response:body('{"error":"tenant_tokens_revoked","message":"All tokens for this tenant have been revoked"}')
            return
        end
    end

    request:headers("X-Revocation-Check", "passed")
    redis:call("QUIT")
end
