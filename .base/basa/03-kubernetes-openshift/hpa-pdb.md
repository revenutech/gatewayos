# HPA + PDB

## Objetivo

Garantir escalabilidade horizontal e tolerância a disrupção voluntária do
Gateway no OpenShift, reutilizando os templates existentes (sem mudanças
estruturais). Documenta diferenças operacionais do OCP (Machine
Autoscaler + Cluster Autoscaler).

## HorizontalPodAutoscaler

Template `templates/hpa.yaml` existente, reutilizado:

```yaml
{{- if .Values.autoscaling.enabled }}
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: {{ include "gateway.fullname" . }}
  namespace: {{ .Release.Namespace }}
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: {{ include "gateway.fullname" . }}
  minReplicas: {{ .Values.autoscaling.minReplicas }}
  maxReplicas: {{ .Values.autoscaling.maxReplicas }}
  metrics:
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: {{ .Values.autoscaling.targetCPUUtilizationPercentage }}
    - type: Resource
      resource:
        name: memory
        target:
          type: Utilization
          averageUtilization: {{ .Values.autoscaling.targetMemoryUtilizationPercentage }}
  behavior:
    scaleDown:
      stabilizationWindowSeconds: 300
      policies:
        - type: Percent
          value: 50
          periodSeconds: 60
    scaleUp:
      stabilizationWindowSeconds: 0
      policies:
        - type: Percent
          value: 100
          periodSeconds: 30
        - type: Pods
          value: 2
          periodSeconds: 30
      selectPolicy: Max
{{- end }}
```

### Defaults por env (ver `values-per-env.md`)

| Env | minReplicas | maxReplicas | targetCPU | targetMem |
|---|---|---|---|---|
| dev | 1 | 3 | 70 | 80 |
| staging | 2 | 6 | 60 | 75 |
| prod | 3 | 10 | 60 | 75 |

### Metrics custom (opcional)

`requests-per-second` via Prometheus Adapter + metrics-server. Escopo
Fase 04.

```yaml
metrics:
  - type: Pods
    pods:
      metric:
        name: http_requests_per_second
      target:
        type: AverageValue
        averageValue: 500
```

Exige Prometheus Adapter instalado; v1 fica na lista.

## PodDisruptionBudget

Template `templates/pdb.yaml` reutilizado:

```yaml
{{- if .Values.pdb.enabled }}
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: {{ include "gateway.fullname" . }}
  namespace: {{ .Release.Namespace }}
spec:
  {{- if .Values.pdb.minAvailable }}
  minAvailable: {{ .Values.pdb.minAvailable }}
  {{- else }}
  maxUnavailable: {{ .Values.pdb.maxUnavailable | default 1 }}
  {{- end }}
  selector:
    matchLabels:
      app.kubernetes.io/name: gateway
      app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}
```

### Defaults por env

| Env | PDB |
|---|---|
| dev | `maxUnavailable: 1` (libera drain livre) |
| staging | `maxUnavailable: 1` |
| prod | `minAvailable: 2` (sempre 2 pods up em janela de manutenção) |

## Interação com Machine Autoscaler (OCP)

HPA escala **pods**; se não houver nodes disponíveis, pods ficam Pending.
OCP resolve com **Machine Autoscaler** (MAO) provisionando novos nodes.

Config (pós-install, via `oc apply`):

```yaml
apiVersion: autoscaling.openshift.io/v1beta1
kind: MachineAutoscaler
metadata:
  name: gateway-basa-{env}-worker-a
  namespace: openshift-machine-api
spec:
  minReplicas: 1
  maxReplicas: 4
  scaleTargetRef:
    apiVersion: machine.openshift.io/v1beta1
    kind: MachineSet
    name: gateway-basa-{env}-worker-a
```

E o ClusterAutoscaler global:

```yaml
apiVersion: autoscaling.openshift.io/v1
kind: ClusterAutoscaler
metadata:
  name: default
spec:
  resourceLimits:
    maxNodesTotal: 12
  scaleDown:
    enabled: true
    delayAfterAdd: 10m
    delayAfterDelete: 10s
    delayAfterFailure: 3m
    unneededTime: 10m
```

Estes CRs **não** são parte do chart — ficam em `02-iac-terraform-oci/` ou
em bootstrap manifests separados.

## Requests / Limits — impacto no autoscaling

HPA exige `resources.requests` definido. Reutilizar do chart:

```yaml
resources:
  requests:
    cpu: 250m
    memory: 128Mi
  limits:
    cpu: 1000m
    memory: 512Mi
```

Em prod Basa, aumentar para `cpu: 500m / memory: 256Mi` (request) dada a
capacidade maior dos workers E4.Flex 4/16.

## Drain e rolling update

Deployment strategy:

```yaml
strategy:
  type: RollingUpdate
  rollingUpdate:
    maxSurge: 1
    maxUnavailable: 0
```

Combinado com PDB `minAvailable: 2` em prod → rolling garante sempre pelo
menos 2 pods ativos durante rollout.

## Graceful shutdown

KrakenD responde SIGTERM limpo. Configurar no deployment:

```yaml
terminationGracePeriodSeconds: 30
lifecycle:
  preStop:
    exec:
      command: ["/bin/sh", "-c", "sleep 10"]   # drena conexões do LB antes de SIGTERM
```

## Decisões de design

1. **HPA reutilizado** — mesma lógica CPU+memory.
2. **PDB reforçado em prod** (`minAvailable: 2` em vez de `maxUnavailable: 1`).
3. **Machine Autoscaler separado** do chart — responsabilidade do cluster.
4. **PreStop sleep 10s** — evita 502 durante rollout.
5. **Custom metrics via Prometheus Adapter** fica em Fase 04.

## Controles ISO 27001

- A.8.6 — Capacity management.
- A.8.14 — Redundancy of information processing facilities.
- A.5.30 — ICT readiness for business continuity.

## Checklist pronto-para-código

- [ ] HPA renderiza com mínimos/máximos por env.
- [ ] PDB prod renderiza `minAvailable: 2`.
- [ ] MachineAutoscaler aplicado (fora do chart).
- [ ] Rolling update com `maxUnavailable: 0`.
- [ ] PreStop presente, SIGTERM limpo (teste: `kubectl delete pod` sem 502).
- [ ] Teste de stress reproduz scale-up + scale-down.
