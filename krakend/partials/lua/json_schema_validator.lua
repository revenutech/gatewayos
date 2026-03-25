-- =============================================================================
-- JSON Schema Request Validator
-- Enterprise KrakenD equivalent: validation/json-schema (request body validation)
--
-- Validates incoming request bodies against predefined schemas.
-- Schema is selected based on the endpoint path and HTTP method.
--
-- Validation rules:
-- - Required fields presence
-- - Field type checking (string, number, boolean, array, object)
-- - String length limits (min/max)
-- - Number range limits (min/max)
-- - Enum validation
-- - Pattern matching (regex)
--
-- Lightweight implementation — does NOT support full JSON Schema Draft-07.
-- For complex schemas, use the OpenAPI validator in the CI pipeline instead.
-- =============================================================================

-- Schema registry: endpoint_pattern -> { required_fields, field_rules }
local SCHEMAS = {
    ["POST:/v1/postings"] = {
        required = {"amount", "currency", "debit_account", "credit_account"},
        fields = {
            amount = { type = "number", min = 0.01 },
            currency = { type = "string", enum = {"BRL", "USD", "EUR"} },
            debit_account = { type = "string", min_length = 1, max_length = 64 },
            credit_account = { type = "string", min_length = 1, max_length = 64 },
            description = { type = "string", max_length = 500 },
            metadata = { type = "object" }
        }
    },
    ["POST:/v1/settlements"] = {
        required = {"settlement_date", "accounts"},
        fields = {
            settlement_date = { type = "string", pattern = "^%d%d%d%d%-%d%d%-%d%d$" },
            accounts = { type = "array", min_items = 1 },
            description = { type = "string", max_length = 500 }
        }
    },
    ["POST:/v1/reconciliation/jobs"] = {
        required = {"source", "target", "date_range"},
        fields = {
            source = { type = "string", min_length = 1 },
            target = { type = "string", min_length = 1 },
            date_range = { type = "object" },
            tolerance = { type = "number", min = 0 }
        }
    }
}

-- Simple JSON parser for request body (KrakenD Lua has limited JSON support)
-- Returns a table of top-level key-value pairs
local function parse_json_fields(body)
    local fields = {}
    if not body or body == "" then return fields end

    -- Extract top-level string fields
    for key, value in body:gmatch('"([^"]+)"%s*:%s*"([^"]*)"') do
        fields[key] = { value = value, type = "string" }
    end

    -- Extract top-level number fields
    for key, value in body:gmatch('"([^"]+)"%s*:%s*(%d+%.?%d*)') do
        if not fields[key] then
            fields[key] = { value = tonumber(value), type = "number" }
        end
    end

    -- Extract top-level boolean fields
    for key, value in body:gmatch('"([^"]+)"%s*:%s*(true)') do
        fields[key] = { value = true, type = "boolean" }
    end
    for key, value in body:gmatch('"([^"]+)"%s*:%s*(false)') do
        fields[key] = { value = false, type = "boolean" }
    end

    -- Detect array fields (simplified)
    for key in body:gmatch('"([^"]+)"%s*:%s*%[') do
        if not fields[key] then
            fields[key] = { value = "[]", type = "array" }
        end
    end

    -- Detect object fields (simplified)
    for key in body:gmatch('"([^"]+)"%s*:%s*%{') do
        if not fields[key] then
            fields[key] = { value = "{}", type = "object" }
        end
    end

    return fields
end

function pre_proxy(request)
    local method = request:method()
    local endpoint = request:url()

    -- Only validate POST/PUT/PATCH with JSON body
    if method ~= "POST" and method ~= "PUT" and method ~= "PATCH" then
        return
    end

    local content_type = request:headers("Content-Type") or ""
    if not content_type:find("application/json") then
        return
    end

    -- Find matching schema
    local schema_key = method .. ":" .. endpoint
    local schema = SCHEMAS[schema_key]

    -- No schema for this endpoint — allow through
    if not schema then
        return
    end

    local body = request:body()
    if not body or body == "" then
        local response = request:response()
        response:statusCode(400)
        response:headers("Content-Type", "application/json")
        response:body('{"error":"validation_error","message":"Request body is required","endpoint":"' .. endpoint .. '"}')
        return
    end

    local fields = parse_json_fields(body)
    local errors = {}

    -- Check required fields
    for _, field_name in ipairs(schema.required or {}) do
        if not fields[field_name] then
            table.insert(errors, { field = field_name, error = "required field is missing" })
        end
    end

    -- Check field rules
    for field_name, rules in pairs(schema.fields or {}) do
        local field = fields[field_name]
        if field then
            -- Type check
            if rules.type and field.type ~= rules.type then
                table.insert(errors, { field = field_name, error = "expected type " .. rules.type .. ", got " .. field.type })
            end

            -- String length checks
            if field.type == "string" then
                local len = #tostring(field.value)
                if rules.min_length and len < rules.min_length then
                    table.insert(errors, { field = field_name, error = "minimum length is " .. rules.min_length })
                end
                if rules.max_length and len > rules.max_length then
                    table.insert(errors, { field = field_name, error = "maximum length is " .. rules.max_length })
                end
                -- Enum check
                if rules.enum then
                    local valid = false
                    for _, v in ipairs(rules.enum) do
                        if field.value == v then valid = true; break end
                    end
                    if not valid then
                        table.insert(errors, { field = field_name, error = "must be one of: " .. table.concat(rules.enum, ", ") })
                    end
                end
                -- Pattern check
                if rules.pattern and not tostring(field.value):find(rules.pattern) then
                    table.insert(errors, { field = field_name, error = "does not match expected pattern" })
                end
            end

            -- Number range checks
            if field.type == "number" then
                if rules.min and field.value < rules.min then
                    table.insert(errors, { field = field_name, error = "minimum value is " .. rules.min })
                end
                if rules.max and field.value > rules.max then
                    table.insert(errors, { field = field_name, error = "maximum value is " .. rules.max })
                end
            end
        end
    end

    -- Return validation errors
    if #errors > 0 then
        local error_msgs = {}
        for _, err in ipairs(errors) do
            table.insert(error_msgs, '"' .. err.field .. ': ' .. err.error .. '"')
        end

        local response = request:response()
        response:statusCode(422)
        response:headers("Content-Type", "application/json")
        response:body('{"error":"validation_error","message":"Request body validation failed","errors":[' .. table.concat(error_msgs, ",") .. ']}')
        return
    end

    -- Validation passed
    request:headers("X-Schema-Validated", "true")
end
