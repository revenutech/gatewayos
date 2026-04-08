# Logging

## Configuration

```json
"telemetry/logging": {
  "level": "{{ .service.log_level }}",
  "prefix": "[KRAKEND]",
  "stdout": true,
  "format": "logstash"
}
```

## Log Levels by Environment

| Environment | Level | Verbosity |
|-------------|-------|-----------|
| Dev | DEBUG | All messages including request details |
| Staging | INFO | Operational messages, no debug details |
| Production | WARNING | Only warnings and errors |

## Format

**Logstash** (JSON structured) format. Each log entry is a JSON object with:
- `@timestamp`
- `level`
- `message`
- `prefix` — always `[KRAKEND]`

## Lua-Based Logging

### Access Logging (access_log.lua)

Post-proxy hook that logs structured access information:
- Request method, path, status code
- Response time
- Client info (User-Agent, IP)
- Correlation ID

### Audit Evidence (audit_evidence.lua)

ISO 27001 A.5.28/A.8.15 compliant audit logging:
- User identity (X-User-ID)
- Tenant context (X-Tenant-ID)
- Action performed
- Timestamp
- Outcome (success/failure)

## Error Message Behavior

| Environment | `return_error_msg` | Client sees |
|-------------|-------------------|-------------|
| Dev | true | Detailed error messages including backend errors |
| Staging | false | Generic error messages |
| Production | false | Generic error messages |

Backend errors are always logged internally, regardless of `return_error_msg` setting.

## Log Collection

In K8s, logs are written to stdout and collected by the cluster's log aggregation pipeline (e.g., Fluentd, Loki, Cloud Logging).
