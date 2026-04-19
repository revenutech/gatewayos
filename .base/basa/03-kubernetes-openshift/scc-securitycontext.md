# SecurityContextConstraints (SCC)

## Objetivo

Garantir que o pod do Gateway obedeça ao padrão OpenShift de atribuição
aleatória de UID e aplique proteções de hardening mandatórias (non-root,
no privilege escalation, read-only fs, drop ALL capabilities).

## Componentes relevantes

| Item | Comportamento |
|---|---|
| UID do container | SCC escolhe UID do range do namespace (`openshift.io/sa.scc.uid-range`) |
| GID | SCC atribui GID 0 por default (compat com `chgrp -R 0` no filesystem) |
| fsGroup | SCC `fsGroup: RunAsAny` / `MustRunAs` conforme escolhido |
| Pod Security Admission | `restricted` label aplicada no namespace |
| Baseline de SCC | `restricted-v2` (shipped com OCP 4.12+) |

## SCC padrão a usar — `restricted-v2`

Shipped com OCP 4.12+. Equivalente moderno do `restricted`. Bloqueia:

- `runAsUser: MustRunAsRange` (força UID do range do namespace).
- `seLinuxContext: MustRunAs`.
- `fsGroup: MustRunAs`.
- Capabilities: `requiredDropCapabilities: [ALL]`, `allowedCapabilities: []`.
- `allowPrivilegedContainer: false`.
- `allowPrivilegeEscalation: false`.
- `seccompProfile`: `RuntimeDefault`.
- Volume types: limitados (configMap, downwardAPI, emptyDir, projected,
  secret, persistentVolumeClaim, ephemeral).

**Decisão v1:** usar `restricted-v2` (sem SCC custom) — Gateway é stateless
e compatível com todas as restrições.

## Ajustes no template `deployment.yaml`

### Pod-level `securityContext`

```yaml
securityContext:
  runAsNonRoot: true
  # runAsUser / runAsGroup / fsGroup: omitidos — SCC atribui
  seccompProfile:
    type: RuntimeDefault
```

### Container-level `securityContext`

**Sem mudança**:

```yaml
securityContext:
  allowPrivilegeEscalation: false
  readOnlyRootFilesystem: true
  capabilities:
    drop:
      - ALL
  runAsNonRoot: true
```

## Filesystem layout compatível com UID random

Dockerfile.ubi9 (Fase 01) já trata:

- `chgrp -R 0 /etc/krakend /home/krakend`.
- `chmod -R g=rwX /etc/krakend /home/krakend`.
- `/etc/krakend` read-only é ok — config é imutável.
- Se algum processo precisar escrever, montar `emptyDir` no path
  (ex: `/tmp` em KrakenD — KrakenD não escreve em /tmp por default).

## SCC custom — quando criar

Criar SCC custom **só se** `restricted-v2` não cobrir. Casos possíveis:

- **Precisa `runAsUser` fixo** (FIPS exige UID específico? — não exige).
- **Precisa capability** (`NET_BIND_SERVICE` para portas <1024 — KrakenD
  roda em :8080, não precisa).
- **Precisa hostPath** (não — stateless).

V1 **não cria SCC custom**. Se precisar no futuro, padrão abaixo.

## Template Helm — `templates/scc.yaml` (quando ativado)

```yaml
{{- if and .Values.openshift.enabled .Values.openshift.scc.create }}
apiVersion: security.openshift.io/v1
kind: SecurityContextConstraints
metadata:
  name: {{ .Values.openshift.scc.name }}
  labels:
    {{- include "gateway.labels" . | nindent 4 }}
allowHostDirVolumePlugin: false
allowHostIPC: false
allowHostNetwork: false
allowHostPID: false
allowHostPorts: false
allowPrivilegeEscalation: false
allowPrivilegedContainer: false
allowedCapabilities: []
defaultAddCapabilities: []
requiredDropCapabilities:
  - ALL
fsGroup:
  type: MustRunAs
  ranges:
    - min: 1000
      max: 2000
runAsUser:
  type: MustRunAsRange
  uidRangeMin: 1000
  uidRangeMax: 2000
seLinuxContext:
  type: MustRunAs
seccompProfiles:
  - runtime/default
supplementalGroups:
  type: MustRunAs
  ranges:
    - min: 1000
      max: 2000
volumes:
  - configMap
  - downwardAPI
  - emptyDir
  - persistentVolumeClaim
  - projected
  - secret
  - ephemeral
users: []
groups: []
{{- end }}
```

Binding:
```yaml
kind: RoleBinding
metadata:
  name: {{ include "gateway.fullname" . }}-scc
  namespace: {{ .Release.Namespace }}
roleRef:
  kind: ClusterRole
  name: system:openshift:scc:{{ .Values.openshift.scc.name }}
subjects:
  - kind: ServiceAccount
    name: {{ include "gateway.serviceAccountName" . }}
    namespace: {{ .Release.Namespace }}
```

## Pod Security Admission (PSA)

Namespace `gateway-{env}` anotado com:

```
pod-security.kubernetes.io/enforce: restricted
pod-security.kubernetes.io/audit: restricted
pod-security.kubernetes.io/warn: restricted
```

`restricted-v2` SCC + PSA `restricted` são compatíveis. Dupla camada de
defesa.

## Compliance Operator (OCP)

OpenShift Compliance Operator roda **CIS OpenShift Benchmark** e gera
relatórios. Runbook em Fase 08 descreve:

- `ScanSettingBinding` `ocp4-cis` rodando semanalmente.
- Remediação automática de non-compliant **desabilitada** (manual review).
- Relatórios em `openshift-compliance` namespace.

## Decisões de design

1. **`restricted-v2` default** — sem SCC custom v1.
2. **`runAsUser` removido** do deployment quando OpenShift — deixa SCC
   assignar.
3. **GID 0 + chgrp 0** no Dockerfile — compat com UID random.
4. **PSA restricted** no namespace — camada extra.
5. **Compliance Operator** — evidência pronta para auditoria.

## Controles ISO 27001

- A.8.2 — Privileged access.
- A.8.9 — Configuration management.
- A.8.25 — Secure development life cycle (hardening build → deploy).
- A.5.15 — Access control.

## Checklist pronto-para-código

- [ ] `runAsUser` condicional no deployment template.
- [ ] PSA labels no namespace.
- [ ] Pod inicia com UID do range (`id` no container mostra UID random).
- [ ] `readOnlyRootFilesystem: true` funciona (nenhum erro de escrita).
- [ ] Compliance Operator scan sem críticos.
- [ ] SCC custom **não** existe v1 (documentado).
