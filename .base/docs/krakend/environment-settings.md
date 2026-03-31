# Environment Settings

Comparison of `dev.json`, `staging.json`, and `prod.json` settings files.

## Service Configuration

| Setting | Dev | Staging | Production |
|---------|-----|---------|------------|
| port | 8080 | 8080 | 8080 |
| log_level | DEBUG | INFO | WARNING |
| return_error_msg | true | false | false |

## Keycloak / JWT

| Setting | Dev | Staging | Production |
|---------|-----|---------|------------|
| JWKS URL | auth.allenty.io | auth-staging.revenu.com.br | auth.revenu.com.br |
| Issuer | auth.allenty.io/realms/ledgeros | auth-staging.revenu.com.br/realms/ledgeros | auth.revenu.com.br/realms/ledgeros |
| Audience | revenu-platform | revenu-platform | revenu-platform |

## OAuth2

| Setting | Dev | Staging | Production |
|---------|-----|---------|------------|
| client_id | krakend-gateway | krakend-gateway | krakend-gateway |
| client_secret | Hardcoded (dev only) | `${OAUTH2_CLIENT_SECRET}` | `${OAUTH2_CLIENT_SECRET}` |

## API Keys

| Setting | Dev | Staging | Production |
|---------|-----|---------|------------|
| registry | 2 test keys | Empty | Empty |

Dev test keys: `dev-test-key-001` (viewer+operator) and `dev-test-key-002` (admin).

## Backend Addresses

| Backend | Dev | Staging | Production |
|---------|-----|---------|------------|
| ledgeros_http | ledgeros:8081 | ledgeros.ledgeros-staging.svc.cluster.local:8081 | ledgeros.ledgeros-production.svc.cluster.local:8081 |
| ledgeros_grpc | ledgeros:9081 | ledgeros.ledgeros-staging.svc.cluster.local:9081 | ledgeros.ledgeros-production.svc.cluster.local:9081 |
| paymentos | paymentos:8082 | paymentos.ledgeros-staging.svc:8082 | paymentos.ledgeros-production.svc:8082 |
| atmos | atmos:8088 | atmos.ledgeros-staging.svc:8088 | atmos.ledgeros-production.svc:8088 |
| identos | identos:8091 | identos.ledgeros-staging.svc:8091 | identos.ledgeros-production.svc:8091 |
| onboardos | onboardos:8092 | onboardos.ledgeros-staging.svc:8092 | onboardos.ledgeros-production.svc:8092 |
| accountos | accountos:8093 | accountos.ledgeros-staging.svc:8093 | accountos.ledgeros-production.svc:8093 |
| financeos | financeos:8095 | financeos.ledgeros-staging.svc:8095 | financeos.ledgeros-production.svc:8095 |
| grpc_transcoder | envoy-grpc-transcoder:8085 | 127.0.0.1:8085 | 127.0.0.1:8085 |

**Pattern:** Dev uses Docker Compose DNS. Staging/Prod use K8s full DNS (`{service}.ledgeros-{env}.svc.cluster.local`). gRPC transcoder switches from Docker DNS to localhost (sidecar).

## Redis

| Setting | Dev | Staging | Production |
|---------|-----|---------|------------|
| Host | redis | redis.ledgeros-staging.svc.cluster.local | redis.ledgeros-production.svc.cluster.local |
| Port | 6379 | 6379 | 6379 |

## Rate Limits

| Setting | Dev | Staging | Production |
|---------|-----|---------|------------|
| Global max (default) | 5,000/min | 5,000/min | **10,000/min** |
| Tenant max (default) | 500/min | 500/min | **1,000/min** |
| Postings write global | 1,000/min | 1,000/min | 1,000/min |
| Postings write tenant | 100/min | 100/min | 100/min |
| Balances read global | 5,000/min | 5,000/min | 5,000/min |
| Balances read tenant | 500/min | 500/min | 500/min |

Production has 2x default rate limits compared to dev/staging.

## CORS Origins

| Environment | Allowed Origins |
|-------------|----------------|
| Dev | `http://localhost:3000`, `http://localhost:8081` |
| Staging | `https://staging.revenu.com.br` |
| Production | `https://app.revenu.com.br` |

Methods, headers, and max_age are identical across environments.

## Circuit Breakers

Circuit breaker configuration is **identical across all environments**. See [circuit-breakers.md](../security/circuit-breakers.md) for details.
