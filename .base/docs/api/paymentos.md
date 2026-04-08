# Paymentos Routes

Backend: `paymentos:8082`

Paymentos handles payment processing for Brazilian payment rails: PIX (instant), TED (bank transfer), and Boleto (payment slip).

## Endpoints

### POST /v1/pix/{path}

Initiate PIX operations (create payment, confirm, cancel, etc.).

- **Roles:** ledger-operator, ledger-admin
- **Circuit breaker:** cb-paymentos (3 errors / 60s / 15s timeout)
- **Encoding:** no-op (passthrough)

### GET /v1/pix/{path}

Query PIX operations (status, history, receipts, etc.).

- **Roles:** ledger-viewer, ledger-operator, ledger-admin
- **Circuit breaker:** cb-paymentos

### POST /v1/ted/{path}

Initiate TED bank transfers.

- **Roles:** ledger-operator, ledger-admin
- **Circuit breaker:** cb-paymentos

### POST /v1/boleto/{path}

Generate and manage Boletos.

- **Roles:** ledger-operator, ledger-admin
- **Circuit breaker:** cb-paymentos

## Wildcard Routing Pattern

All Paymentos routes use the `{path}` wildcard pattern. The gateway forwards the full sub-path to the backend without transformation:

```
Gateway: /v1/pix/payments/create  -->  Backend: /v1/pix/payments/create
Gateway: /v1/pix/keys/list        -->  Backend: /v1/pix/keys/list
Gateway: /v1/ted/transfers/123    -->  Backend: /v1/ted/transfers/123
```

This allows Paymentos to add new sub-routes without gateway config changes. The `no-op` encoding ensures request/response bodies are passed through without JSON manipulation.

## Circuit Breaker Rationale

Paymentos uses the strictest CB config among standard services (3 max errors vs 5 for most others) because:
- Payment operations are critical financial transactions
- Failed payments should fail fast rather than queue up
- 15s recovery timeout allows time for transient PSP issues to resolve

## Headers Propagated

```
X-User-ID, X-Tenant-ID, X-Roles, X-Correlation-ID, Content-Type
```

Note: PIX GET endpoints do not propagate `Content-Type` (no request body).
