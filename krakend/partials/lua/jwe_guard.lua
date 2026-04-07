-- =============================================================================
-- JWE Token Guard — CVE-2026-34986 Mitigation
-- ISO 27001: A.8.5 (Secure authentication), A.12.4.1 (Event logging)
--
-- Rejects JWE-format tokens (5 dot-separated segments) before they reach
-- the go-jose library, preventing a panic in JWE decryption.
-- This gateway uses RS256 (JWS, 3 segments) exclusively.
--
-- JWS format: header.payload.signature          (3 segments)
-- JWE format: header.key.iv.ciphertext.tag      (5 segments)
-- =============================================================================

function check_jwe(request)
    local auth = request:headers("Authorization")
    if not auth or auth == "" then
        return
    end

    -- Extract Bearer token
    local token = auth:match("^[Bb]earer%s+(.+)$")
    if not token then
        return
    end

    -- Count dot-separated segments
    local count = 0
    for _ in token:gmatch("[^%.]+") do
        count = count + 1
    end

    -- JWE tokens have exactly 5 segments — reject them
    if count == 5 then
        local response = request:response()
        response:statusCode(400)
        response:headers("Content-Type", "application/json")
        response:body('{"error":"unsupported_token_type","message":"JWE tokens are not accepted. This API requires JWS (RS256) tokens."}')
        print("[SECURITY] Blocked JWE token attempt from " .. (request:headers("X-Forwarded-For") or "unknown"))
        return
    end

    -- Also reject tokens with unexpected segment counts (not 3 for JWS)
    if count ~= 3 then
        local response = request:response()
        response:statusCode(400)
        response:headers("Content-Type", "application/json")
        response:body('{"error":"malformed_token","message":"Invalid token format."}')
        print("[SECURITY] Blocked malformed token (segments=" .. count .. ") from " .. (request:headers("X-Forwarded-For") or "unknown"))
        return
    end
end
