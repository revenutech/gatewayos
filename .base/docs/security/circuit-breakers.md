# Circuit Breakers

Two circuit breaker implementations protect backends from cascading failures.

## 1. Native KrakenD Circuit Breaker

Built-in `qos/circuit-breaker`. Simple closed→open→closed state machine.

```json
"qos/circuit-breaker": {
  "interval": 60,
  "timeout": 10,
  "max_errors": 5,
  "name": "cb-ledgeros-posting",
  "log_status_change": true
}
```

**Behavior:**
- **Closed:** Normal operation. Counts consecutive errors.
- **Open:** When `max_errors` failures occur within `interval` seconds. All requests return 503 immediately.
- **Recovery:** After `timeout` seconds, the circuit closes and allows traffic again.

## 2. Custom Lua Circuit Breaker

Redis-backed (`circuit_breaker_custom.lua`) with half-open state support.

**States:**
- **Closed:** Normal. Error count tracked in Redis.
- **Open:** All requests rejected. State expires after `recovery_time`.
- **Half-open:** Allows up to 3 probe requests to test recovery. If probes succeed, circuit closes. If probes fail, circuit reopens.

Advantages over native:
- **Distributed state** via Redis (all gateway instances share CB state)
- **Half-open state** for gradual recovery
- **Persistent** across pod restarts

## Per-Backend Configuration

Values are identical across dev/staging/prod:

| Backend | CB Name | Max Errors | Interval (s) | Timeout (s) | Rationale |
|---------|---------|-----------|---------------|-------------|-----------|
| LedgerOS HTTP | cb-ledgeros-posting | 5 | 60 | 10 | Standard — core accounting |
| LedgerOS gRPC | cb-ledgeros-grpc | 5 | 60 | 10 | Standard — mirrors HTTP |
| Paymentos | cb-paymentos | **3** | 60 | **15** | Strict — payment operations are critical, fail fast |
| AtmOS | cb-atmos | **10** | **120** | **30** | Lenient — tolerates intermittent ATM failures |
| Identos | cb-identos | **2** | **30** | **5** | Very strict — auth must fail fast |
| OnboardOS | cb-onboardos | 5 | 60 | 10 | Standard |
| AccountOS | cb-accountos | 5 | 60 | 10 | Standard |
| FinanceOS | cb-financeos | 5 | 60 | **15** | Standard with longer recovery |

## Design Rationale

**Identos (strictest: 2/30/5):** Auth failures should be detected immediately. A broken auth service affects all authenticated operations. Fast open + fast recovery.

**Paymentos (strict: 3/60/15):** Payment operations involve real money. Better to fail fast than process duplicates. Longer recovery allows PSP transient issues to resolve.

**AtmOS (lenient: 10/120/30):** ATM/hardware operations are inherently unreliable. More tolerance for errors, wider window, longer recovery for hardware-dependent systems.

## Monitoring

Circuit breaker state changes are:
- Logged: `[KRAKEND] circuit breaker {name} changed to OPEN/CLOSED`
- Alerted: PrometheusRule `KrakenDCircuitBreakerOpen` triggers after 1 minute
