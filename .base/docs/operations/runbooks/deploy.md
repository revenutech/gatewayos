---
title: "Runbook: Deploy API Gateway"
iso_ref: "A.5.37 (Documented operating procedures), A.8.32 (Change management)"
---

# Deploy API Gateway

## Standard Deployment (CI/CD)
```bash
# 1. Create PR with changes
git checkout -b feature/my-change
# ... make changes ...
git commit -m "description"
git push origin feature/my-change

# 2. CI validates automatically:
#    - krakend check (config syntax)
#    - JSON lint (settings validation)
#    - Config audit (compliance check)
#    - Docker build test

# 3. After PR approval + merge to main:
#    - CI computes config hash
#    - Updates deployment annotation
#    - Rolling update triggers (maxSurge:1, maxUnavailable:0)

# 4. Verify
kubectl get pods -l app.kubernetes.io/name=krakend
curl -s https://api.revenu.com.br/__health
```

## Manual Deployment (Emergency)
```bash
# Only for P1/P2 incidents; requires post-hoc review within 24h
kubectl set image deployment/krakend krakend=devopsfaith/krakend:2.13.3 --record
kubectl rollout status deployment/krakend
```

## Verification Checklist
- [ ] All pods Running and Ready
- [ ] `/__health` returns 200
- [ ] `/__ready` returns 200 (backend connectivity)
- [ ] Prometheus scraping active
- [ ] No new alerts in last 5 minutes
