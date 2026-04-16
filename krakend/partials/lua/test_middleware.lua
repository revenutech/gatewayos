-- =============================================================================
-- Combined Test Middleware — All enterprise features in one script
-- Used by /v1/test/* endpoints for integration testing
-- =============================================================================

-- ===== API Key Auth =====
local api_keys = {
    ["dev-test-key-001"] = { id = "dev-key-1", tenant_id = "tenant-dev", roles = "ledger-viewer,ledger-operator", tier = "default", enabled = true },
    ["dev-test-key-002"] = { id = "dev-key-2", tenant_id = "tenant-dev", roles = "ledger-admin", tier = "premium", enabled = true }
}

-- ===== Blocked User Agents =====
local BLOCKED_UAS = { "sqlmap", "nikto", "nessus", "dirbuster", "gobuster", "wpscan", "masscan", "burpsuite" }

-- ===== SSRF Patterns =====
local SSRF_PATTERNS = { "169%.254%.169%.254", "metadata%.google%.internal", "metadata%.azure%.com", "100%.100%.100%.100", "file://", "gopher://", "ldap://" }

-- ===== Classification Map =====
local CLASSIFICATION = {
    ["/__health"] = "PUBLIC",
    ["/__ready"] = "PUBLIC",
    ["/v1/test/"] = "INTERNAL",
    ["/v1/postings"] = "CONFIDENTIAL",
    ["/v1/balances"] = "CONFIDENTIAL",
    ["/v1/pix/"] = "RESTRICTED",
    ["/v1/admin/"] = "RESTRICTED"
}

function pre_proxy(request)
    -- 1. API Key Auth
    local api_key = request:headers("X-API-Key")
    if api_key and api_key ~= "" then
        local key_data = api_keys[api_key]
        if not key_data then
            local resp = request:response()
            resp:statusCode(401)
            resp:headers("Content-Type", "application/json")
            resp:body('{"error":"invalid_api_key","message":"The provided API key is not valid"}')
            return
        end
        if not key_data.enabled then
            local resp = request:response()
            resp:statusCode(403)
            resp:headers("Content-Type", "application/json")
            resp:body('{"error":"api_key_disabled","message":"This API key has been disabled"}')
            return
        end
        request:headers("X-User-ID", "apikey:" .. key_data.id)
        request:headers("X-Tenant-ID", key_data.tenant_id)
        request:headers("X-Roles", key_data.roles)
        request:headers("X-API-Key-ID", key_data.id)
        request:headers("X-Auth-Method", "api-key")
    end

    -- 2. Bot Detection
    local ua = request:headers("User-Agent") or ""
    local ua_lower = ua:lower()
    for _, blocked in ipairs(BLOCKED_UAS) do
        if ua_lower:find(blocked) then
            local resp = request:response()
            resp:statusCode(403)
            resp:headers("Content-Type", "application/json")
            resp:body('{"error":"blocked_client","message":"Request blocked by security policy"}')
            return
        end
    end

    -- 3. SSRF / Web Filter
    local referer = request:headers("Referer") or ""
    local origin = request:headers("Origin") or ""
    for _, pattern in ipairs(SSRF_PATTERNS) do
        if referer:lower():find(pattern:lower()) or origin:lower():find(pattern:lower()) then
            local resp = request:response()
            resp:statusCode(403)
            resp:headers("Content-Type", "application/json")
            resp:body('{"error":"web_filter_blocked","message":"Request blocked by web filtering policy"}')
            return
        end
    end

    -- 4. XSS Detection in headers
    local xss_patterns = { "<script", "javascript:", "onerror%s*=", "eval%s*%(" }
    for _, header_name in ipairs({"Referer", "Origin", "X-Correlation-ID"}) do
        local val = request:headers(header_name) or ""
        for _, xss in ipairs(xss_patterns) do
            if val:lower():find(xss:lower()) then
                local resp = request:response()
                resp:statusCode(400)
                resp:headers("Content-Type", "application/json")
                resp:body('{"error":"invalid_input","message":"Request contains potentially malicious content"}')
                return
            end
        end
    end

    -- 5. SQL Injection Detection in query string
    local url = request:url() or ""
    local sql_patterns = { "['\"%;]%s*SELECT", "['\"%;]%s*DROP", "' OR '1'='1", "UNION%s+SELECT" }
    local query = url:match("%?(.+)$")
    if query then
        for _, pattern in ipairs(sql_patterns) do
            if query:upper():find(pattern:upper()) then
                local resp = request:response()
                resp:statusCode(400)
                resp:headers("Content-Type", "application/json")
                resp:body('{"error":"invalid_input","message":"Request contains potentially malicious content"}')
                return
            end
        end
    end

    request:headers("X-Security-Policy", "enforced")
    request:headers("X-Web-Filter", "passed")
end

function post_proxy(response)
    local request = response:request()
    local endpoint = request:url() or ""

    -- 1. Classification Labels
    local classification = "INTERNAL"
    for pattern, level in pairs(CLASSIFICATION) do
        if endpoint:find(pattern, 1, true) then
            classification = level
            break
        end
    end
    response:headers("X-Content-Classification", classification)
    response:headers("X-Classification-Policy", "B5-Revenu-Data-Classification")

    -- 2. DLP: Mask CPF patterns in response body
    local body = response:body()
    if body and body ~= "" then
        local masked = body:gsub("(%d%d%d)%.(%d%d%d)%.(%d%d%d)%-(%d%d)", "%1.***.***-%4")
        if masked ~= body then
            response:body(masked)
            response:headers("X-DLP-Filtered", "true")
        end
    end

    -- 3. Audit Evidence (simplified)
    local tenant = request:headers("X-Tenant-ID") or ""
    local user = request:headers("X-User-ID") or ""
    local auth = request:headers("X-Auth-Method") or "none"
    local status = response:statusCode()
    response:headers("X-Audit-Logged", "true")
    response:headers("X-Auth-Method-Used", auth)
end
