# Envoy gRPC-REST Transcoder

Sidecar that replaces KrakenD Enterprise's native `backend/grpc` feature.

## How it works

```
Client -> KrakenD (:8080) -> Envoy (:8085) -> LedgerOS gRPC (:9081)
           REST/JSON          REST->gRPC          gRPC/protobuf
```

KrakenD routes `/grpc/v1/*` endpoints to Envoy, which transcodes the JSON request
into a gRPC call to LedgerOS and returns the gRPC response as JSON.

## Proto descriptor

The transcoder needs a compiled proto descriptor file (`ledgeros.pb`).
Generate it from the LedgerOS proto files:

```bash
protoc \
  --include_imports \
  --include_source_info \
  --descriptor_set_out=envoy/proto/ledgeros.pb \
  -I /path/to/ledgeros/proto \
  ledgeros/v1/*.proto
```

Place the resulting `ledgeros.pb` in `envoy/proto/`.

## Environments

| Environment | Envoy Address | Config |
|-------------|--------------|--------|
| Dev (Docker Compose) | `envoy-grpc-transcoder:8085` | `envoy/envoy-dev.yaml` |
| K8s (Sidecar) | `127.0.0.1:8085` | `k8s/manifests/envoy-grpc-configmap.yaml` |
