# OpenShift Route

**Arquiteto Principal:** Gustavo Armoa

## Objetivo

Expor o Gateway externamente via **OpenShift Route** com terminação TLS
gerenciada por cert-manager, redirect HTTP→HTTPS e (opcional) WAF via
HAProxy Router annotations.

## Características

| Aspecto | Detalhe |
|---|---|
| API | `route.openshift.io/v1` |
| Certificado | `Certificate` cert-manager + Secret referenciado pelo Route |
| Redirect HTTP→HTTPS | `spec.tls.insecureEdgeTerminationPolicy: Redirect` |
| Health check | Readiness do Pod (sem config extra) |
| Connection drain | HAProxy Router |
| Shard | Default Ingress Controller |
| Multi-path | `Route` = 1 host + 1 path; múltiplos paths = múltiplas Routes |

## Tipos de terminação TLS

| Tipo | Descrição | Quando usar |
|---|---|---|
| **edge** | TLS termina no Router; tráfego Router→Pod é HTTP | **default** — cert-manager emite, simples |
| **passthrough** | TLS passa direto; Pod termina TLS | Se Gateway precisar ver cert client raw |
| **reencrypt** | TLS termina no Router, re-encrypta até o Pod | Se exigir mTLS Router↔Pod |

**Decisão Basa v1:** `edge`. Pod continua aceitando HTTP interno (porta
8080). Router e Pod estão no mesmo cluster + NetworkPolicy — nível de
confiança suficiente.

Opção `reencrypt` fica plano B se exigirmos mTLS intra-cluster (depende
do mesh ou service-ca — ADR-003 contempla).

## Template Helm — `templates/route.yaml`

```yaml
{{- if and .Values.openshift.enabled .Values.openshift.route.enabled }}
apiVersion: route.openshift.io/v1
kind: Route
metadata:
  name: {{ include "gateway.fullname" . }}
  namespace: {{ .Release.Namespace }}
  labels:
    {{- include "gateway.labels" . | nindent 4 }}
  annotations:
    haproxy.router.openshift.io/timeout: "30s"
    haproxy.router.openshift.io/balance: "roundrobin"
    haproxy.router.openshift.io/disable_cookies: "true"
    {{- with .Values.openshift.route.annotations }}
    {{- toYaml . | nindent 4 }}
    {{- end }}
spec:
  host: {{ .Values.openshift.route.host | quote }}
  to:
    kind: Service
    name: {{ include "gateway.fullname" . }}
    weight: 100
  port:
    targetPort: http
  tls:
    termination: {{ .Values.openshift.route.tlsTermination | default "edge" }}
    insecureEdgeTerminationPolicy: {{ .Values.openshift.route.insecureEdgeTerminationPolicy | default "Redirect" }}
    {{- if .Values.certManager.enabled }}
    # Certificado gerenciado por cert-manager — Route referencia Secret
    # via externalCertificate (feature alpha; fallback: operator writes secret).
    externalCertificate:
      name: {{ include "gateway.fullname" . }}-cert
    {{- end }}
  wildcardPolicy: {{ .Values.openshift.route.wildcardPolicy | default "None" }}
{{- end }}
```

## `externalCertificate` — alternativa e fallback

`externalCertificate` em Route ainda é **alpha feature** (OCP 4.16+).
Precisa:
- `featureGate: RouteExternalCertificate` habilitado no cluster.
- RBAC do cert-manager para operar em Routes.

**Fallback estável** — cert-manager grava Secret TLS e Route referencia
diretamente:

```yaml
tls:
  termination: edge
  certificate: |
    {{ .certificate }}         # vindo de ExternalSecret ou SecretStore + patch
  key: |
    {{ .key }}
```

Preferimos **não** colar cert inline no Route (não é imutável, sujo). V1
adota **fluxo 2 recursos**:

1. `Certificate` CR (cert-manager) escreve Secret `gateway-tls`.
2. Route referencia via `externalCertificate` (se available) **ou** via
   um reconciliador (`cert-utils-operator` — third-party) que copia do
   Secret para o Route automaticamente.

Alternativa nativa: instalar o **cert-manager Operator for Red Hat
OpenShift** (supported) que adiciona `CertUtilsOperator`-like reconciler
como feature supported.

## Template Helm — `templates/certificate.yaml`

```yaml
{{- if .Values.certManager.enabled }}
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: {{ include "gateway.fullname" . }}-cert
  namespace: {{ .Release.Namespace }}
  labels:
    {{- include "gateway.labels" . | nindent 4 }}
spec:
  secretName: {{ include "gateway.fullname" . }}-tls
  issuerRef:
    kind: {{ .Values.certManager.issuerRef.kind }}
    name: {{ .Values.certManager.issuerRef.name }}
  commonName: {{ .Values.certManager.commonName }}
  dnsNames:
    {{- range .Values.certManager.dnsNames }}
    - {{ . | quote }}
    {{- end }}
  duration: {{ .Values.certManager.duration }}
  renewBefore: {{ .Values.certManager.renewBefore }}
  usages:
    - server auth
    - digital signature
    - key encipherment
  privateKey:
    algorithm: RSA
    encoding: PKCS1
    size: 2048
    rotationPolicy: Always
{{- end }}
```

## HTTP → HTTPS redirect

OpenShift Route com `insecureEdgeTerminationPolicy: Redirect`:

- Router escuta em :80 e :443 por default.
- Request HTTP → responde 302 para o mesmo host HTTPS.

## HSTS

Ativar via annotation (controlador global ou na Route):

```
haproxy.router.openshift.io/hsts_header: "max-age=31536000;includeSubDomains;preload"
```

## Timeouts e idle

```
haproxy.router.openshift.io/timeout: "30s"              # server timeout
haproxy.router.openshift.io/timeout-tunnel: "60s"       # websocket
```

## Multi-host (se houver mais de um domínio)

OCP Route é **1 host por objeto**. Para `gateway.oci.allenty.io` +
`api.gateway.oci.allenty.io`: duas Routes, mesmo Service.

## Decisões de design

1. **Edge termination** — simplicidade, cert-manager padrão.
2. **Redirect HTTP→HTTPS** — sem exposição em `:80`.
3. **HSTS on** — A.8.24.
4. **Sem WAF na v1** — OCI WAF fica ADR futuro se precisar bloquear ataques
   camada 7.
5. **Um host, uma Route** — sem WildcardPolicy.

## Controles ISO 27001

- A.8.20 — Networks security (exposição controlada).
- A.8.24 — Cryptography (TLS + HSTS).
- A.8.23 — Web filtering (HSTS preload).

## Checklist pronto-para-código

- [ ] `templates/route.yaml` renderiza corretamente sob `openshift.enabled`.
- [ ] `templates/certificate.yaml` emite via cert-manager uat em sqa.
- [ ] HTTP → HTTPS redirect validado (`curl -I http://...`).
- [ ] HSTS header presente.
- [ ] Route funciona após cert-manager renovar.

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
