# IdentityOS Routes

Backend: `identityos:8091`

IdentityOS handles identity management and authentication services.

## Endpoints

### POST /v1/auth/{path}

Authentication operations (login, token refresh, password reset, etc.).

- **Roles:** JWT required, **no role restriction** — any authenticated user can access
- **Circuit breaker:** cb-identityos (2 errors / 30s / 5s timeout)
- **Encoding:** no-op

### GET /v1/users/{path}

User management and directory operations.

- **Roles:** ledger-admin **only**
- **Circuit breaker:** cb-identityos
- **Encoding:** no-op

## Circuit Breaker Rationale

IdentityOS has the **strictest** CB configuration:
- **2 max errors** — auth failures must fail fast (credential stuffing protection)
- **30s interval** — short evaluation window
- **5s timeout** — quick recovery attempts

This ensures that auth service degradation is detected and isolated immediately, preventing cascading auth failures across the platform.

## Design Note

The `/v1/auth/*` endpoint does not enforce RBAC roles because it handles pre-authentication operations (login, token exchange). The JWT is still required for validation, but the `auth/validator` roles check is omitted.
