---
title: "Runbook: TLS/mTLS Certificate Rotation"
iso_ref: "A.8.24 (Cryptography), A.5.14 (Information transfer)"
---

# TLS/mTLS Certificate Rotation

## Automatic (cert-manager)
cert-manager renews certificates 30 days before expiry automatically.
Monitor via: `KrakenDCertExpiringIn30Days` alert.

## Emergency Rotation
```bash
# 1. Delete the current secret (cert-manager will reissue)
kubectl delete secret krakend-mtls-client-cert

# 2. Verify cert-manager reissues
kubectl get certificate krakend-mtls-client -w

# 3. Restart KrakenD to pick up new cert
kubectl rollout restart deployment/krakend

# 4. Verify mTLS working
kubectl logs -l app.kubernetes.io/name=krakend --tail=50 | grep -i tls
```

## Keycloak JWKS Key Rotation
KrakenD caches JWKS keys for 1h (`cache_duration: 3600`).
If Keycloak rotates keys:
1. `failed_jwk_key_cooldown: 10s` handles automatic re-fetch
2. No manual action required unless Keycloak is down
