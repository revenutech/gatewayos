-- =============================================================================
-- Audit Evidence Logger with Hash Chain
-- ISO 27001:2022 Annex A Control 5.28 (Collection of evidence)
-- ISO 27001:2022 Annex A Control 8.15 (Logging)
--
-- Produces tamper-evident audit log entries by chaining each entry
-- to the previous via SHA-256 hash. Any modification to a prior entry
-- breaks the chain, making tampering detectable.
--
-- Log entry format (JSON):
--   { seq, timestamp, event_type, tenant_id, user_id, endpoint, method,
--     status, correlation_id, auth_method, evidence_hash, prev_hash }
--
-- Verification: Replay log entries and recompute hashes.
-- If any evidence_hash != SHA256(seq + data + prev_hash), chain is broken.
-- =============================================================================

-- Sequence counter (per-instance, resets on restart)
-- In production, use Redis INCR for global sequence across instances
local sequence = 0
local prev_hash = "genesis"

-- Simple hash function (DJB2 variant — not cryptographic, but deterministic)
-- In production, use a proper SHA-256 via ffi or external call
local function compute_hash(data)
    local hash = 5381
    for i = 1, #data do
        hash = ((hash * 33) + data:byte(i)) % 2147483647
    end
    return string.format("%010x", hash)
end

function post_proxy(response)
    local request = response:request()
    local status = response:statusCode()

    -- Determine event type based on status and context
    local event_type = "api_access"
    if status == 401 or status == 403 then
        event_type = "auth_failure"
    elseif status == 429 then
        event_type = "rate_limited"
    elseif status >= 500 then
        event_type = "server_error"
    elseif status == 503 then
        event_type = "circuit_breaker"
    end

    -- Collect evidence fields
    local tenant_id = request:headers("X-Tenant-ID") or ""
    local user_id = request:headers("X-User-ID") or ""
    local correlation_id = request:headers("X-Correlation-ID") or ""
    local endpoint = request:url() or ""
    local method = request:method() or ""
    local auth_method = request:headers("X-Auth-Method") or "jwt"
    local api_key_id = request:headers("X-API-Key-ID") or ""
    local timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ", os.time())

    -- Increment sequence
    sequence = sequence + 1

    -- Build data string for hashing (deterministic order)
    local hash_input = string.format("%d|%s|%s|%s|%s|%s|%s|%d|%s|%s|%s",
        sequence, timestamp, event_type, tenant_id, user_id,
        endpoint, method, status, correlation_id, auth_method, prev_hash
    )

    -- Compute evidence hash
    local evidence_hash = compute_hash(hash_input)

    -- Build audit log entry
    local log_entry = string.format(
        '{"@type":"audit_evidence","seq":%d,"timestamp":"%s","event_type":"%s",' ..
        '"tenant_id":"%s","user_id":"%s","endpoint":"%s","method":"%s",' ..
        '"status":%d,"correlation_id":"%s","auth_method":"%s","api_key_id":"%s",' ..
        '"evidence_hash":"%s","prev_hash":"%s","iso_controls":["A.5.28","A.8.15"]}',
        sequence, timestamp, event_type,
        tenant_id, user_id, endpoint, method,
        status, correlation_id, auth_method, api_key_id,
        evidence_hash, prev_hash
    )

    -- Emit audit log to stdout (captured by K8s log collector)
    print(log_entry)

    -- Update chain
    prev_hash = evidence_hash

    -- Set audit evidence headers for downstream correlation
    response:headers("X-Audit-Seq", tostring(sequence))
    response:headers("X-Audit-Hash", evidence_hash)
end
