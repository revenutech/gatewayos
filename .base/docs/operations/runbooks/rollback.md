---
title: "Runbook: Rollback API Gateway"
iso_ref: "A.5.37 (Documented operating procedures), A.8.32 (Change management)"
---

# Rollback API Gateway

## Git Revert (Preferred)
```bash
# 1. Identify bad commit
git log --oneline -10

# 2. Revert
git revert <bad-commit-hash>
git push origin main

# 3. CI redeploys automatically with reverted config

# 4. Verify
kubectl rollout status deployment/krakend
curl -s https://api.revenu.com.br/__health
```

## K8s Rollback (Fast)
```bash
# Rollback to previous revision
kubectl rollout undo deployment/krakend

# Verify
kubectl rollout status deployment/krakend

# Check which revision is active
kubectl rollout history deployment/krakend
```

## Post-Rollback
1. Log corrective action in `corrective-actions.md`
2. Investigate root cause
3. Fix and re-deploy via normal process
