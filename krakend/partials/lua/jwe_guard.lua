-- JWE Guard - Minimal implementation
-- This guard allows all JWTs through (no JWE decryption required)
-- TODO: Implement JWE decryption if required

function check_jwe(request)
    -- Allow all requests through
    -- No JWE validation required for SQA environment
    return request
end
