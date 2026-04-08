# Error Codes

## Gateway-Generated Errors

| Status | Cause | When |
|--------|-------|------|
| 401 Unauthorized | JWT validation failure | Invalid/expired/missing token, JWKS fetch failure, audience/issuer mismatch |
| 403 Forbidden | RBAC check failure | User's roles do not include required role for endpoint |
| 429 Too Many Requests | Rate limit exceeded | Global or per-tenant rate limit hit (1-minute window) |
| 503 Service Unavailable | Circuit breaker open | Backend exceeded max_errors within interval; circuit is open |
| 504 Gateway Timeout | Backend timeout | Backend did not respond within endpoint timeout (default 3s) |

## Backend-Passthrough Errors

Most endpoints use `no-op` encoding, meaning backend HTTP status codes and response bodies are passed through to the client without transformation:

| Status | Source | Example |
|--------|--------|---------|
| 400 Bad Request | Backend | Invalid request payload |
| 404 Not Found | Backend | Resource not found |
| 409 Conflict | Backend | Duplicate transaction |
| 422 Unprocessable Entity | Backend | Business rule violation |
| 500 Internal Server Error | Backend | Backend application error |

## Error Response Behavior

### Dev Environment

`return_error_msg: true` — KrakenD returns detailed error messages including backend error details. Useful for debugging.

### Staging/Production

`return_error_msg: false` — KrakenD returns generic error messages. Backend errors are logged but not exposed to clients.

## Correlation Tracking

All requests propagate the `X-Correlation-ID` header. To trace an error:

1. Client receives error response
2. Use `X-Correlation-ID` value to search gateway logs
3. Gateway logs include backend response status and timing
4. Cross-reference with backend logs using the same correlation ID

## Aggregated Endpoint Errors

Dashboard endpoints (`/v1/dashboard/*`) query multiple backends. If one backend fails:
- The failed backend's group is **omitted** from the response
- Other backends' data is still returned (partial response)
- The endpoint returns 200 even with partial data
- Returns 500 only if all backends fail

## Rate Limit Headers

When rate limited (429), KrakenD includes:
- `Retry-After` header indicating when the client can retry
- Rate limit is per X-Tenant-ID header (1-minute sliding window)

## Circuit Breaker Behavior

When a circuit breaker is open:
- All requests to that backend immediately return 503
- The circuit remains open for `timeout` seconds
- After timeout, the circuit enters half-open state (custom Lua CB) or attempts recovery (native CB)
- Status changes are logged: `[KRAKEND] circuit breaker {name} changed to OPEN/CLOSED`
