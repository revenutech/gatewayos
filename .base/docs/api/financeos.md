# FinanceOS Routes

Backend: `financeos:8095`

FinanceOS handles financial operations.

## Endpoints

| Path | Method | Roles | Description |
|------|--------|-------|-------------|
| `/v1/finance/{path}` | POST | operator, admin | Create financial operations |
| `/v1/finance/{path}` | GET | viewer, operator, admin | Query financial data |

## Configuration

- **Circuit breaker:** cb-financeos (5 errors / 60s / 15s timeout)
- **Encoding:** no-op (passthrough)
- **Headers:** X-User-ID, X-Tenant-ID, X-Roles, X-Correlation-ID, Content-Type, X-Subscription-Tier

Note: FinanceOS has a slightly longer CB timeout (15s vs 10s standard) to account for complex financial calculations.
