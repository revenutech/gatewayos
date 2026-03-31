# OnboardOS Routes

Backend: `onboardos:8092`

OnboardOS handles customer onboarding including KYC, AML screening, due diligence, document management, and lifecycle management. It exposes 21 route prefixes through the gateway.

## Route Prefixes

Each prefix supports 4 HTTP methods with consistent RBAC:

| # | Prefix | Domain |
|---|--------|--------|
| 1 | `/v1/onboarding/{path}` | Onboarding journeys and workflows |
| 2 | `/v1/kyc/{path}` | Know-Your-Customer pipeline |
| 3 | `/v1/dd/{path}` | Due diligence processes |
| 4 | `/v1/journeys/{path}` | Customer journey management |
| 5 | `/v1/documents/{path}` | Document upload and verification |
| 6 | `/v1/leads/{path}` | Sales leads management |
| 7 | `/v1/risk/{path}` | Risk assessment |
| 8 | `/v1/rio/{path}` | RIO (Risk and Intelligence Operations) |
| 9 | `/v1/aml/{path}` | Anti-Money Laundering checks |
| 10 | `/v1/screenings/{path}` | PEP/sanctions screening |
| 11 | `/v1/cases/{path}` | Investigation cases |
| 12 | `/v1/policies/{path}` | Compliance policies |
| 13 | `/v1/reviews/{path}` | Review workflows |
| 14 | `/v1/offboarding/{path}` | Customer offboarding |
| 15 | `/v1/mdm/{path}` | Master Data Management |
| 16 | `/v1/audit/{path}` | Audit trail |
| 17 | `/v1/sessions/{path}` | Onboarding sessions |
| 18 | `/v1/milestones/{path}` | Journey milestones |
| 19 | `/v1/notifications/{path}` | Notification management |
| 20 | `/v1/business-entities/{path}` | Business entity management |
| 21 | `/v1/cnpj/{path}` | Brazilian company registry (CNPJ) lookup |

## RBAC Pattern (per prefix)

| Method | Roles | Use Case |
|--------|-------|----------|
| GET | ledger-viewer, ledger-operator, ledger-admin | Read onboarding data |
| POST | ledger-operator, ledger-admin | Create new records |
| PUT | ledger-operator, ledger-admin | Update existing records |
| DELETE | ledger-admin | Delete records (admin only) |

## Total Effective Endpoints

21 prefixes x 4 methods = **~84 effective endpoints**

Each prefix uses wildcard `{path}` routing, so the actual number of backend routes is much larger. Examples:

```
POST /v1/kyc/verifications/start     --> POST onboardos:8092/v1/kyc/verifications/start
GET  /v1/aml/screenings/123/results  --> GET  onboardos:8092/v1/aml/screenings/123/results
PUT  /v1/documents/456/approve       --> PUT  onboardos:8092/v1/documents/456/approve
```

## Configuration

- **Circuit breaker:** cb-onboardos (5 errors / 60s / 10s timeout)
- **Encoding:** no-op (passthrough) for all endpoints
- **Headers:** X-User-ID, X-Tenant-ID, X-Roles, X-Correlation-ID, Content-Type, X-Subscription-Tier
