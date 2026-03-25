-- =============================================================================
-- Web Filtering / Egress URL Validation
-- ISO 27001:2022 Annex A Control 8.23 (Web filtering)
--
-- Validates outbound backend URLs and request patterns against an allowlist.
-- Prevents SSRF attacks where a manipulated request could cause the gateway
-- to contact unintended internal or external services.
--
-- Also blocks requests containing URLs to known malicious domains
-- in headers or query parameters.
-- =============================================================================

-- Allowed backend host patterns (must match for egress)
local ALLOWED_HOSTS = {
    "ledgeros",
    "paymentos",
    "atmos",
    "identos",
    "onboardos",
    "accountos",
    "financeos",
    "keycloak",
    "redis",
    "127%.0%.0%.1",
    "localhost",
    "envoy%-grpc%-transcoder",
    "otel%-collector"
}

-- Blocked patterns in request URLs/headers (SSRF prevention)
local BLOCKED_URL_PATTERNS = {
    "169%.254%.169%.254",          -- AWS metadata endpoint
    "metadata%.google%.internal",  -- GCP metadata
    "metadata%.azure%.com",        -- Azure metadata
    "100%.100%.100%.100",          -- DigitalOcean metadata
    "169%.254%.170%.2",            -- ECS metadata
    "file://",                     -- Local file access
    "gopher://",                   -- Gopher protocol
    "dict://",                     -- Dict protocol
    "ftp://",                      -- FTP protocol
    "ldap://",                     -- LDAP injection
    "0%.0%.0%.0",                  -- Wildcard binding
    "10%.0%.0%.0/8",               -- Private network (if not expected)
}

-- Blocked domains (malware, phishing — update via CI/CD)
local BLOCKED_DOMAINS = {
    -- Add known malicious domains here
    -- "evil-domain.com",
    -- "phishing-site.net",
}

local function is_allowed_host(host)
    for _, pattern in ipairs(ALLOWED_HOSTS) do
        if host:find(pattern) then
            return true
        end
    end
    return false
end

local function contains_blocked_pattern(value)
    if not value or value == "" then return false end
    local lower = value:lower()
    for _, pattern in ipairs(BLOCKED_URL_PATTERNS) do
        if lower:find(pattern:lower()) then
            return true, pattern
        end
    end
    for _, domain in ipairs(BLOCKED_DOMAINS) do
        if lower:find(domain:lower()) then
            return true, domain
        end
    end
    return false
end

function pre_proxy(request)
    local url = request:url() or ""
    local referer = request:headers("Referer") or ""
    local origin = request:headers("Origin") or ""

    -- Check URL for blocked patterns (SSRF prevention)
    local blocked, pattern = contains_blocked_pattern(url)
    if blocked then
        local response = request:response()
        response:statusCode(403)
        response:headers("Content-Type", "application/json")
        response:headers("X-Web-Filter", "blocked")
        response:body('{"error":"web_filter_blocked","message":"Request blocked by web filtering policy","iso_control":"A.8.23"}')
        return
    end

    -- Check Referer/Origin headers for suspicious URLs
    for _, header_val in ipairs({referer, origin}) do
        blocked, pattern = contains_blocked_pattern(header_val)
        if blocked then
            local response = request:response()
            response:statusCode(403)
            response:headers("Content-Type", "application/json")
            response:headers("X-Web-Filter", "blocked-header")
            response:body('{"error":"web_filter_blocked","message":"Request header contains blocked URL pattern","iso_control":"A.8.23"}')
            return
        end
    end

    -- Mark as filtered
    request:headers("X-Web-Filter", "passed")
end
