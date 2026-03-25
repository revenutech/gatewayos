---
title: "Runbook: Scale API Gateway"
iso_ref: "A.8.6 (Capacity management), A.8.14 (Redundancy)"
---

# Scale API Gateway

## HPA (Automatic)
HPA scales between 2-8 pods based on CPU/memory.
```bash
# Check current state
kubectl get hpa krakend

# View scaling events
kubectl describe hpa krakend
```

## Manual Scale (Override HPA)
```bash
# Scale up for expected load
kubectl scale deployment krakend --replicas=6

# NOTE: HPA will override this. To persist, update HPA:
kubectl patch hpa krakend -p '{"spec":{"minReplicas":4}}'

# Reset to normal
kubectl patch hpa krakend -p '{"spec":{"minReplicas":2}}'
```

## Capacity Monitoring
- Alert: `KrakenDCapacityAtMaximum` (HPA at max for 15min)
- Dashboard: Grafana → KrakenD Security → Capacity panel
- Rate limit 429s indicate capacity pressure
