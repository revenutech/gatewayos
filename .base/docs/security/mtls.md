# mTLS Backend Communication

Mutual TLS for secure gateway-to-backend connections.

## Configuration

```json
"backend/http/client": {
  "client_tls": {
    "allow_insecure_connections": false,
    "ca_certs": "/etc/krakend/tls/ca.crt",
    "client_certs": [{
      "certificate": "/etc/krakend/tls/client.crt",
      "private_key": "/etc/krakend/tls/client.key"
    }],
    "disable_system_ca_pool": false,
    "min_version": "TLS12",
    "max_version": "TLS13",
    "cipher_suites": [
      "TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384",
      "TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256",
      "TLS_AES_256_GCM_SHA384",
      "TLS_AES_128_GCM_SHA256"
    ],
    "curve_preferences": ["CurveP256", "CurveP384"]
  }
}
```

## TLS Settings

| Setting | Value |
|---------|-------|
| Minimum TLS version | 1.2 |
| Maximum TLS version | 1.3 |
| Insecure connections | Disabled |
| System CA pool | Enabled (fallback) |

## Cipher Suites

Listed in preference order:

1. `TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384` — TLS 1.2, strongest
2. `TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256` — TLS 1.2, fast
3. `TLS_AES_256_GCM_SHA384` — TLS 1.3
4. `TLS_AES_128_GCM_SHA256` — TLS 1.3

All use AEAD (Authenticated Encryption with Associated Data) and forward secrecy (ECDHE).

## Curve Preferences

- P256 (prime256v1) — preferred, fastest
- P384 (secp384r1) — fallback, stronger

## Certificate Management

### Kubernetes

Certificates are mounted from a K8s Secret:

```yaml
volumes:
  - name: mtls-certs
    secret:
      secretName: krakend-mtls-client-cert
      items:
        - key: tls.crt  → /etc/krakend/tls/client.crt
        - key: tls.key  → /etc/krakend/tls/client.key
        - key: ca.crt   → /etc/krakend/tls/ca.crt
```

### Certificate Monitoring

PrometheusRule alerts for certificate expiry:
- **KrakenDCertExpiringIn30Days** — warning (ISO A.8.24)
- **KrakenDCertExpiringIn7Days** — critical (ISO A.8.24)

Expects cert-manager to handle automatic renewal.

## ISO 27001 References

- **A.8.24** — Management of technical vulnerabilities (certificate lifecycle)
- **A.5.14** — Information transfer (encryption in transit)
