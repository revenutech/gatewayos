# OpenShift Logging — Loki

**Arquiteto Principal:** Gustavo Armoa

## Objetivo

Coletar logs de pods (stdout/stderr) com **OpenShift Logging** (Vector
collector + Loki storage) e expor via Grafana. Opcional: forward para OCI
Logging.

## Características

| Item | Detalhe |
|---|---|
| Storage | Loki com backend S3-compat (OCI Object Storage) + archive |
| Collector | Vector (default OCP 4.13+) |
| Outputs | ClusterLogForwarder suporta múltiplos outputs (Loki default + opcional OCI Logging) |
| Retenção | 30d quente + archive 7 anos |

## Instalação

Dois operators:

1. **Red Hat OpenShift Logging** — `openshift-logging` operator.
2. **Loki Operator** — backend de logs.

```yaml
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: cluster-logging
  namespace: openshift-logging
spec:
  channel: stable
  name: cluster-logging
  source: redhat-operators
  sourceNamespace: openshift-marketplace
---
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: loki-operator
  namespace: openshift-operators-redhat
spec:
  channel: stable
  name: loki-operator
  source: redhat-operators
  sourceNamespace: openshift-marketplace
```

## LokiStack CR

```yaml
apiVersion: loki.grafana.com/v1
kind: LokiStack
metadata:
  name: logging-loki
  namespace: openshift-logging
spec:
  size: 1x.small               # 1x.small (sqa/uat), 1x.medium (pro)
  storage:
    schemas:
      - version: v13
        effectiveDate: "2026-01-01"
    secret:
      name: loki-objstore
      type: s3
  storageClassName: oci-bv
  tenants:
    mode: openshift-logging
  retention:
    global:
      days: 30
    streams:
      - days: 7
        priority: 1
        selector: '{log_type="infrastructure"}'
      - days: 30
        priority: 2
        selector: '{log_type="application"}'
      - days: 90
        priority: 3
        selector: '{log_type="audit"}'
```

Backend **OCI Object Storage** (bucket `revenu-platform-loki-{env}`)
acessado via S3-compatibility. Secret `loki-objstore` com:

```yaml
endpoint: https://{namespace}.compat.objectstorage.{region}.oraclecloud.com
bucketnames: revenu-platform-loki-{env}
access_key_id: {customer_secret_key_id}
access_key_secret: {customer_secret_key}
```

## ClusterLogForwarder + ClusterLogging

```yaml
apiVersion: logging.openshift.io/v1
kind: ClusterLogging
metadata:
  name: instance
  namespace: openshift-logging
spec:
  managementState: Managed
  collection:
    type: vector
    vector:
      resources:
        requests:
          cpu: 100m
          memory: 128Mi
        limits:
          cpu: 500m
          memory: 512Mi
  logStore:
    type: lokistack
    lokistack:
      name: logging-loki
---
apiVersion: logging.openshift.io/v1
kind: ClusterLogForwarder
metadata:
  name: instance
  namespace: openshift-logging
spec:
  outputs:
    - name: default-loki
      type: loki
      loki:
        labelKeys:
          - kubernetes.namespace_name
          - kubernetes.pod_name
          - kubernetes.container_name
          - log_type
        # default output já aponta para LokiStack logging-loki
    # opcional — forward OCI Logging
    - name: oci-logging
      type: http
      url: https://ingestion.logging.{region}.oci.oraclecloud.com/20200831/actions/putLogs
      http:
        method: POST
        headers:
          Authorization: ${env:OCI_SIGNED_AUTH_HEADER}
          Content-Type: application/json
  pipelines:
    - name: app-logs
      inputRefs:
        - application
      outputRefs:
        - default-loki
      filterRefs:
        - drop-debug
    - name: infra-audit
      inputRefs:
        - infrastructure
        - audit
      outputRefs:
        - default-loki
        # - oci-logging             # opcional
  filters:
    - name: drop-debug
      type: drop
      drop:
        - test:
            - field: .level
              matches: "debug|trace"
```

## Labels e parsing

Vector default label set:

```
log_type               = application | infrastructure | audit
kubernetes.namespace_name
kubernetes.pod_name
kubernetes.container_name
kubernetes.node_name
```

KrakenD emite logs JSON estruturados — habilitar `json` parser:

```
- name: parse-json
  type: parse
  parse: json
```

## Retention e archive

- **Quente (Loki):** 30d para app, 90d para audit, 7d para infra.
- **Archive:** Loki compacta para Object Storage (`boltdb-shipper` +
  `tsdb`). Via lifecycle no bucket, objetos > 90 dias movem para
  **Archive Tier** (OCI Object Storage Archive) — custo 10× menor,
  restore sob demanda.
- **Retention total:** 7 anos para audit (A.5.33).

## Access control

`openshift-logging` mode:
- Admin vê todos os logs via Console → Observe → Logs.
- Usuários com `view` em namespace veem apenas logs do seu namespace.

## Query de exemplo

LogQL via Grafana ou Console:

```
{log_type="application", kubernetes.namespace_name=~"gateway-.*"} |= "error"
{log_type="application", kubernetes.namespace_name="gateway-pro"} | json | status >= 500
```

## Forward OCI Logging (bridge)

Detalhado em `oci-logging-integration.md`. Usa HTTP output com signed
request para `ingestion.logging.{region}.oci.oraclecloud.com`.

## Decisões de design

1. **Vector collector** — default OCP 4.13+, mais eficiente que Fluentd.
2. **LokiStack com Object Storage S3-compat** — integração nativa OCI.
3. **Retention por log_type** — infra 7d (ruído), app 30d, audit 90d+7 anos.
4. **Forward OCI Logging opcional** — habilitar se audit OCI-side exigido.
5. **Label keys mínimas** — evita explosão de cardinality.

## Controles ISO 27001

- A.8.15 — Logging.
- A.8.16 — Monitoring activities.
- A.5.33 — Protection of records (retention + archive).
- A.8.12 — Data leakage prevention (parsing filtra PII se necessário).

## Checklist pronto-para-código

- [ ] Operators Cluster Logging + Loki instalados.
- [ ] LokiStack CR rodando; buckets OCI acessíveis.
- [ ] ClusterLogging + ClusterLogForwarder aplicados.
- [ ] Logs do Gateway visíveis em Grafana Explore (Loki datasource).
- [ ] Retention respeita política.
- [ ] Lifecycle do bucket move >90d para Archive tier.
- [ ] Forward OCI Logging testado (se ativado).

---

## Disclaimer — Recomendação Base

Este documento é uma **recomendação técnica de referência** elaborada como
baseline para o **Banco da Amazônia (BASA)** e **não constitui garantia
de segurança, conformidade regulatória ou funcionamento em produção**.

### Implementação por equipe especializada

A adoção e implementação efetiva deste plano **deve ser conduzida por
uma equipe DevSecOps especializada** nas seguintes tecnologias:

- **Oracle Cloud Infrastructure (OCI)** — arquitetura, IAM, networking,
  Vault, OCIR, observabilidade, compliance.
- **Red Hat OpenShift Container Platform (OCP)** — operação self-managed
  do cluster, SCC, Operators, Compliance Operator, atualizações.
- **Red Hat Enterprise Linux / UBI** — hardening, FIPS mode, supply
  chain de imagens, Red Hat Container Certification.

A ausência de profissionais com essa especialização inviabiliza a
execução segura deste plano.

### Governança de segurança — responsabilidade do Banco da Amazônia

A **governança de segurança da informação do Banco da Amazônia** deve
ser implementada, mantida e auditada com base na família de normas
**ISO/IEC 27000**:

- **ISO/IEC 27001:2022** — requisitos para sistemas de gestão de
  segurança da informação (ISMS).
- **ISO/IEC 27002:2022** — controles de segurança (Annex A, 93 controles).
- **ISO/IEC 27003** — diretrizes de implementação do ISMS.
- **ISO/IEC 27004** — monitoramento, medição, análise e avaliação de
  desempenho do ISMS.
- **ISO/IEC 27005** — gestão de riscos de segurança da informação.

Adicionalmente, **todas as boas práticas de segurança** aplicáveis ao
setor financeiro brasileiro devem ser incorporadas:

- NIST Cybersecurity Framework (CSF).
- CIS Benchmarks (Kubernetes, OpenShift, Red Hat Enterprise Linux).
- OWASP Top 10 / ASVS / SAMM.
- Resoluções **BACEN** (nº 4.893/2021 — Política de Segurança Cibernética,
  Resolução Conjunta 6/2023, entre outras aplicáveis a instituições
  financeiras).
- **Lei Geral de Proteção de Dados (LGPD — Lei 13.709/2018)**.
- SANS Critical Security Controls.

### Autoridade final

**O Banco da Amazônia é a autoridade final** sobre:

- A adequação deste plano ao contexto regulatório, operacional e de
  negócio da instituição.
- A aprovação técnica e executiva de qualquer controle, arquitetura ou
  decisão descrita neste documento.
- A implementação, operação, auditoria e evolução contínua do programa
  de segurança da informação.
- A responsabilidade legal, regulatória e contratual decorrente do uso
  deste material.

Este documento **não substitui** parecer jurídico, auditoria
independente, avaliação de risco formal, nem aprovação do Comitê de
Segurança da Informação do Banco da Amazônia.
