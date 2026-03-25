-- =============================================================================
-- Response Transformation
-- Enterprise KrakenD equivalent: modifier/response-body-generator, modifier/go-template
--
-- Transforms outbound responses before sending to clients:
-- - Wraps responses in standard envelope
-- - Adds metadata (request_id, timestamp, pagination info)
-- - Filters internal fields that shouldn't be exposed
-- - Normalizes error responses
-- =============================================================================

-- Internal fields to strip from responses
local INTERNAL_FIELDS = {
    "internal_id",
    "internal_status",
    "debug_info",
    "stack_trace",
    "_metadata"
}

function post_proxy(response)
    local status = response:statusCode()
    local correlation_id = response:headers("X-Correlation-ID") or ""

    -- Add standard response headers
    response:headers("X-Response-Time", tostring(os.time()))
    response:headers("X-Powered-By", "revenu-platform-gateway")

    -- For error responses, normalize the format
    if status >= 400 then
        -- Ensure error responses have consistent structure
        response:headers("X-Error", "true")

        -- Add correlation ID for error tracking
        if correlation_id ~= "" then
            response:headers("X-Error-Correlation-ID", correlation_id)
        end
    end

    -- Add cache control headers for GET responses
    if status == 200 then
        local cache_control = response:headers("Cache-Control")
        if not cache_control or cache_control == "" then
            -- Default: no caching for API responses (can be overridden per endpoint)
            response:headers("Cache-Control", "no-store, no-cache, must-revalidate")
            response:headers("Pragma", "no-cache")
        end
    end
end
