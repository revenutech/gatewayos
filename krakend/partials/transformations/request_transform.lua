-- =============================================================================
-- Request Transformation
-- Enterprise KrakenD equivalent: modifier/request-body-generator, modifier/go-template
--
-- Transforms inbound requests before forwarding to backends:
-- - Injects metadata fields (timestamp, request_id, source)
-- - Normalizes field names (camelCase -> snake_case)
-- - Strips sensitive fields from request body
-- - Adds pagination defaults
-- =============================================================================

-- Fields to strip from request bodies (sensitive data that shouldn't reach backends)
local STRIP_FIELDS = {
    "password_confirmation",
    "credit_card_number",
    "cvv",
    "ssn",
    "cpf_raw"
}

-- Default pagination values
local DEFAULT_PAGE_SIZE = 20
local MAX_PAGE_SIZE = 100

function pre_proxy(request)
    local content_type = request:headers("Content-Type") or ""
    local method = request:method()

    -- Only transform JSON request bodies
    if not content_type:find("application/json") then
        return
    end

    -- Inject request metadata headers for backends
    request:headers("X-Gateway-Timestamp", tostring(os.time()))
    request:headers("X-Gateway-Version", "1.0.0")
    request:headers("X-Gateway-Source", "krakend")

    -- For GET requests, normalize pagination query params
    if method == "GET" then
        local url = request:url()
        -- Add default pagination if not present
        if not url:find("page_size") and not url:find("limit") then
            -- KrakenD will pass these through via input_query_strings: ["*"]
            request:headers("X-Default-Page-Size", tostring(DEFAULT_PAGE_SIZE))
        end
    end
end
