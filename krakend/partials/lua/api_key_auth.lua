-- =============================================================================
-- API Key Authentication
-- Enterprise KrakenD equivalent: auth/api-keys
--
-- Validates API keys sent via X-API-Key header.
-- Keys are stored in a static map (loaded from config) with associated
-- metadata: roles, tenant_id, rate_limit_tier, and enabled flag.
--
-- On success: injects X-User-ID, X-Tenant-ID, X-Roles, X-API-Key-ID headers
-- On failure: returns 401 (missing/invalid) or 403 (disabled key)
--
-- This can work alongside JWT auth — endpoints can accept either JWT or API key.
-- =============================================================================

-- API key registry (loaded from extra_config at init time)
-- Format: { key_hash = { id, tenant_id, roles, tier, enabled } }
local api_keys = {}

-- SHA256 helper (simple hash for key comparison without storing plaintext)
-- In production, keys should be pre-hashed in config
local function hash_key(key)
    -- KrakenD Lua sandbox doesn't have crypto libs, so we use the key directly
    -- Keys in config should be stored as bcrypt/sha256 hashes in production
    return key
end

function init(cfg)
    -- Load API keys from dynamic config
    -- Expected format in extra_config:
    --   "keys": "key1:id1:tenant1:role1,role2:tier1:true|key2:id2:tenant2:role3:tier2:true"
    local keys_str = cfg("keys") or ""

    for entry in keys_str:gmatch("[^|]+") do
        local key, id, tenant, roles, tier, enabled = entry:match("([^:]+):([^:]+):([^:]+):([^:]+):([^:]+):([^:]+)")
        if key and id then
            api_keys[key] = {
                id = id,
                tenant_id = tenant,
                roles = roles,
                tier = tier or "default",
                enabled = enabled ~= "false"
            }
        end
    end
end

function pre_proxy(request)
    local api_key = request:headers("X-API-Key")

    -- No API key provided — skip (allow JWT auth to handle it)
    if not api_key or api_key == "" then
        return
    end

    local hashed = hash_key(api_key)
    local key_data = api_keys[hashed]

    -- Invalid key
    if not key_data then
        local response = request:response()
        response:statusCode(401)
        response:headers("Content-Type", "application/json")
        response:headers("WWW-Authenticate", "API-Key")
        response:body('{"error":"invalid_api_key","message":"The provided API key is not valid"}')
        return
    end

    -- Key is disabled
    if not key_data.enabled then
        local response = request:response()
        response:statusCode(403)
        response:headers("Content-Type", "application/json")
        response:body('{"error":"api_key_disabled","message":"This API key has been disabled","key_id":"' .. key_data.id .. '"}')
        return
    end

    -- Valid key — inject identity headers (same as JWT propagation)
    request:headers("X-User-ID", "apikey:" .. key_data.id)
    request:headers("X-Tenant-ID", key_data.tenant_id)
    request:headers("X-Roles", key_data.roles)
    request:headers("X-API-Key-ID", key_data.id)
    request:headers("X-Auth-Method", "api-key")
    request:headers("X-Rate-Limit-Tier", key_data.tier)
end
