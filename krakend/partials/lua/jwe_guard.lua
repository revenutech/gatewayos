-- JWE Guard - Minimal implementation
-- This guard allows all JWTs through (no JWE decryption required)
-- TODO: Implement JWE decryption if required

function pre_proxy(request)
    -- Allow all requests through
    -- No JWE validation required for SQA environment
    return request
end

function post_proxy(response)
    return response
end
