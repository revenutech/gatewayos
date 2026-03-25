-- =============================================================================
-- Information Classification Labels
-- ISO 27001:2022 Annex A Control 5.13 (Labelling of information)
-- ISO 27001:2022 Annex A Control 5.12 (Classification of information)
--
-- Injects X-Content-Classification headers in API responses based on
-- the endpoint path. Enables downstream systems and clients to understand
-- the sensitivity of the data they receive.
--
-- Classification levels (per B1-GW / B5-Data Classification):
--   PUBLIC       — No restrictions, publicly available data
--   INTERNAL     — Internal use only, not for external sharing
--   CONFIDENTIAL — Restricted access, business-sensitive
--   RESTRICTED   — Highest sensitivity, PII, financial data
-- =============================================================================

-- Endpoint classification map
local CLASSIFICATION = {
    -- Health endpoints — public
    ["/__health"] = "PUBLIC",
    ["/__ready"] = "PUBLIC",

    -- Dashboard — internal (aggregated, non-sensitive)
    ["/v1/dashboard/"] = "INTERNAL",

    -- Ledger — confidential (financial transactions)
    ["/v1/postings"] = "CONFIDENTIAL",
    ["/v1/balances"] = "CONFIDENTIAL",
    ["/v1/settlements"] = "CONFIDENTIAL",
    ["/v1/reconciliation"] = "CONFIDENTIAL",

    -- Payments — restricted (PII-adjacent, financial)
    ["/v1/pix/"] = "RESTRICTED",
    ["/v1/ted/"] = "RESTRICTED",
    ["/v1/boleto/"] = "RESTRICTED",

    -- Identity — restricted (PII)
    ["/v1/auth/"] = "RESTRICTED",
    ["/v1/users/"] = "RESTRICTED",

    -- Admin — restricted
    ["/v1/admin/"] = "RESTRICTED",

    -- Accounts — confidential
    ["/v1/accounts/"] = "CONFIDENTIAL",
    ["/v1/onboarding/"] = "CONFIDENTIAL",
    ["/v1/finance/"] = "CONFIDENTIAL",

    -- Self-service — confidential
    ["/v1/my/"] = "CONFIDENTIAL",

    -- gRPC endpoints — confidential
    ["/grpc/"] = "CONFIDENTIAL"
}

-- Default classification for unmatched endpoints
local DEFAULT_CLASSIFICATION = "INTERNAL"

local function get_classification(endpoint)
    for pattern, level in pairs(CLASSIFICATION) do
        if endpoint:find(pattern, 1, true) then
            return level
        end
    end
    return DEFAULT_CLASSIFICATION
end

function post_proxy(response)
    local request = response:request()
    local endpoint = request:url() or ""
    local classification = get_classification(endpoint)

    -- Set classification headers
    response:headers("X-Content-Classification", classification)
    response:headers("X-Classification-Policy", "B5-Revenu-Data-Classification")
    response:headers("X-Classification-ISO", "ISO27001:A.5.13")
end
