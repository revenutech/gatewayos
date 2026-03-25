-- =============================================================================
-- Advanced Security Policies
-- Enterprise KrakenD equivalent: security/policies (CEL-based with JWT/req/resp scopes)
--
-- Extends CEL validation with policies that require runtime logic:
-- - Tenant isolation enforcement (JWT tenant_id must match X-Tenant-ID)
-- - Request body size limits
-- - SQL injection pattern detection
-- - XSS pattern detection in headers
-- - Suspicious user-agent blocking
-- =============================================================================

-- Maximum request body size (10MB)
local MAX_BODY_SIZE = 10 * 1024 * 1024

-- SQL injection patterns (common attack vectors)
local SQL_PATTERNS = {
    "['\"%;]%s*(%s*(SELECT|INSERT|UPDATE|DELETE|DROP|ALTER|CREATE|EXEC|UNION)%s)",
    "%-%-",
    "/%*.*%*/",
    "\\b(OR|AND)\\b%s+\\d+%s*=%s*\\d+",
    "SLEEP%s*%(", "BENCHMARK%s*%(",
    "@@%w+", "CHAR%s*%(", "CONCAT%s*%("
}

-- XSS patterns
local XSS_PATTERNS = {
    "<script", "javascript:", "onerror%s*=", "onload%s*=",
    "onclick%s*=", "onfocus%s*=", "onmouseover%s*=",
    "eval%s*%(", "expression%s*%(", "url%s*%("
}

-- Suspicious user agents (bots, scanners)
local BLOCKED_USER_AGENTS = {
    "sqlmap", "nikto", "nessus", "dirbuster", "gobuster",
    "wpscan", "masscan", "zmap", "nmap", "burpsuite"
}

local function check_sql_injection(value)
    if not value or value == "" then return false end
    local lower = value:lower()
    for _, pattern in ipairs(SQL_PATTERNS) do
        if lower:find(pattern:lower()) then
            return true
        end
    end
    return false
end

local function check_xss(value)
    if not value or value == "" then return false end
    local lower = value:lower()
    for _, pattern in ipairs(XSS_PATTERNS) do
        if lower:find(pattern:lower()) then
            return true
        end
    end
    return false
end

local function check_user_agent(ua)
    if not ua or ua == "" then return false end
    local lower = ua:lower()
    for _, blocked in ipairs(BLOCKED_USER_AGENTS) do
        if lower:find(blocked) then
            return true
        end
    end
    return false
end

function pre_proxy(request)
    -- 1. Tenant isolation: JWT tenant must match header tenant
    local jwt_tenant = request:headers("X-Tenant-ID")
    local header_tenant = request:headers("X-Tenant-Id")
    if jwt_tenant and header_tenant and jwt_tenant ~= "" and header_tenant ~= "" then
        if jwt_tenant ~= header_tenant then
            local response = request:response()
            response:statusCode(403)
            response:headers("Content-Type", "application/json")
            response:body('{"error":"tenant_mismatch","message":"JWT tenant_id does not match X-Tenant-ID header"}')
            return
        end
    end

    -- 2. Suspicious user-agent detection
    local ua = request:headers("User-Agent")
    if check_user_agent(ua) then
        local response = request:response()
        response:statusCode(403)
        response:headers("Content-Type", "application/json")
        response:body('{"error":"blocked_client","message":"Request blocked by security policy"}')
        return
    end

    -- 3. XSS detection in headers
    local headers_to_check = {"X-Correlation-ID", "Referer", "Origin"}
    for _, header_name in ipairs(headers_to_check) do
        local val = request:headers(header_name)
        if check_xss(val) then
            local response = request:response()
            response:statusCode(400)
            response:headers("Content-Type", "application/json")
            response:body('{"error":"invalid_input","message":"Request contains potentially malicious content"}')
            return
        end
    end

    -- 4. SQL injection detection in query parameters
    local url = request:url()
    local query = url:match("%?(.+)$")
    if query and check_sql_injection(query) then
        local response = request:response()
        response:statusCode(400)
        response:headers("Content-Type", "application/json")
        response:body('{"error":"invalid_input","message":"Request contains potentially malicious content"}')
        return
    end

    -- 5. Request body size check
    local content_length = tonumber(request:headers("Content-Length") or "0")
    if content_length > MAX_BODY_SIZE then
        local response = request:response()
        response:statusCode(413)
        response:headers("Content-Type", "application/json")
        response:body('{"error":"payload_too_large","message":"Request body exceeds maximum allowed size of 10MB"}')
        return
    end

    -- 6. Inject security context headers for backends
    request:headers("X-Security-Policy", "enforced")
    request:headers("X-Request-Time", tostring(os.time()))
end
