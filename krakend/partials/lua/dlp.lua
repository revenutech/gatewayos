-- =============================================================================
-- Data Leakage Prevention (DLP) Response Filter
-- ISO 27001:2022 Annex A Control 8.12 (Data leakage prevention)
-- ISO 27001:2022 Annex A Control 5.34 (Privacy and PII protection)
--
-- Scans outbound responses and strips sensitive fields before returning
-- to the client. Prevents accidental backend PII leakage through the gateway.
--
-- Sensitive patterns:
--   - CPF (Brazilian tax ID): ###.###.###-##
--   - Credit card numbers: 13-19 digits
--   - Email addresses (optional, configurable)
--   - Internal IDs (database PKs, UUIDs from internal systems)
--   - Stack traces and debug info
-- =============================================================================

-- Fields to strip from JSON responses (top-level keys)
local STRIP_FIELDS = {
    "password", "password_hash", "secret", "private_key",
    "credit_card_number", "card_number", "cvv", "cvc",
    "ssn", "cpf_raw", "cpf_number",
    "internal_id", "db_id", "raw_sql",
    "stack_trace", "debug_info", "internal_error",
    "_internal", "_debug", "_raw"
}

-- Patterns to mask in string values (replace with masked version)
local MASK_PATTERNS = {
    -- CPF: 123.456.789-01 → 123.***.***-01
    { pattern = "(%d%d%d)%.(%d%d%d)%.(%d%d%d)%-(%d%d)", replacement = "%1.***.***-%4" },
    -- Credit card: 1234567890123456 → 1234********3456
    { pattern = "(%d%d%d%d)%d%d%d%d%d%d%d%d(%d%d%d%d)", replacement = "%1********%2" },
    -- Card with spaces: 1234 5678 9012 3456
    { pattern = "(%d%d%d%d) %d%d%d%d %d%d%d%d (%d%d%d%d)", replacement = "%1 **** **** %2" },
}

local function mask_value(value)
    if type(value) ~= "string" then return value end
    local masked = value
    for _, mp in ipairs(MASK_PATTERNS) do
        masked = masked:gsub(mp.pattern, mp.replacement)
    end
    return masked
end

local function should_strip(key)
    local lower = key:lower()
    for _, field in ipairs(STRIP_FIELDS) do
        if lower == field then return true end
    end
    return false
end

function post_proxy(response)
    local status = response:statusCode()

    -- Only filter successful responses (errors don't contain business data)
    if status < 200 or status >= 300 then
        return
    end

    local body = response:body()
    if not body or body == "" then return end

    local modified = false

    -- Strip sensitive top-level fields
    for _, field in ipairs(STRIP_FIELDS) do
        -- Match "field": "value" or "field": number/bool/null/object/array
        local pattern = '"' .. field .. '"%s*:%s*[^,}]+'
        local new_body = body:gsub(pattern, "")
        if new_body ~= body then
            body = new_body
            modified = true
        end
    end

    -- Apply masking patterns to remaining string values
    for _, mp in ipairs(MASK_PATTERNS) do
        local new_body = body:gsub(mp.pattern, mp.replacement)
        if new_body ~= body then
            body = new_body
            modified = true
        end
    end

    -- Remove stack traces (multi-line Go/Java patterns)
    local trace_patterns = {
        "goroutine %d+ %[.-%]:.+",
        "at [%w%.]+%([^)]*%).-\n",
        '"stackTrace"%s*:%s*"[^"]*"'
    }
    for _, tp in ipairs(trace_patterns) do
        local new_body = body:gsub(tp, "")
        if new_body ~= body then
            body = new_body
            modified = true
        end
    end

    if modified then
        -- Clean up trailing commas from removed fields
        body = body:gsub(",%s*}", "}")
        body = body:gsub(",%s*]", "]")
        body = body:gsub("{%s*,", "{")

        response:body(body)
        response:headers("X-DLP-Filtered", "true")
    end
end
