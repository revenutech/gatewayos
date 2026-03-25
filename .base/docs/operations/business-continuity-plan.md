---
title: "Business Continuity Plan — API Gateway"
iso_ref: "ISO 27001:2022 A.5.29-5.30"
version: "1.0"
status: Active
owner: DevSecOps Lead
classification: Confidential
---

# Business Continuity Plan — API Gateway

## 1. Recovery Objectives

| Metric | Target | Justification |
|--------|--------|---------------|
| RTO (Recovery Time Objective) | < 5 minutes | Gateway is stateless; K8s restarts pods automatically |
| RPO (Recovery Point Objective) | 0 (zero data loss) | No persistent state; config in Git |
| MTPD (Max Tolerable Period of Disruption) | 15 minutes | Client SLA: 99.9% uptime |

## 2. Resilience Architecture

| Feature | Mechanism | Recovery |
|---------|-----------|----------|
| Pod failure | HPA maintains 2-8 replicas | Automatic (< 30s) |
| Node failure | Pod anti-affinity across hosts | K8s reschedules (< 2min) |
| Backend failure | Circuit breaker (per-backend) | Automatic 503 + Retry-After |
| Redis failure | Fail-open in all Lua scripts | Degraded (local rate limits) |
| Keycloak failure | JWKS cache (1h) | Cached validation continues |
| Config corruption | Git revert + CI redeploy | Manual (< 10min) |
| Full cluster failure | Re-deploy from Git + Docker image | Manual (< 30min) |
| Certificate expiry | cert-manager auto-renewal (30d) | Automatic |

## 3. DR Procedures

### Full Gateway Recovery
```
1. Verify K8s cluster is healthy
2. kubectl apply -f k8s/manifests/  (all manifests)
3. kubectl apply -f k8s/policies/   (network policies)
4. Verify: kubectl get pods -l app.kubernetes.io/name=krakend
5. Health check: curl https://api.revenu.com.br/__health
6. Validate backends: curl https://api.revenu.com.br/v1/dashboard/health
```

### Configuration Recovery
```
1. git log --oneline -10  (find last known good commit)
2. git revert <bad-commit>
3. CI pipeline re-validates and deploys
4. Verify via config-audit: tools/config-audit/audit.sh
```

## 4. Testing

| Test | Frequency | Method |
|------|-----------|--------|
| Pod kill recovery | Monthly | `kubectl delete pod -l app.kubernetes.io/name=krakend --grace-period=0` |
| Circuit breaker test | Quarterly | Simulate backend failure |
| Redis failure test | Quarterly | Stop Redis, verify fail-open |
| Full DR drill | Annually | Rebuild from scratch in staging |
