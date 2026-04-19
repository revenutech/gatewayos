# Helm Chart Structure

**Arquiteto Principal:** Gustavo Armoa

## Objetivo

Estruturar o chart Helm `k8s/helm/gateway/` para deploy OpenShift-flavored
com Route, SCC opcional e Certificate via cert-manager, parametrizável por
env através de `values-oci-{env}.yaml`.

## Valores em `values.yaml`

```yaml
openshift:
  scc:
    create: false       # criar SCC custom (senão usa restricted-v2)
    name: ""
  route:
    enabled: true
    host: ""            # gateway.sqa.oci.allenty.io
    tlsTermination: edge    # edge | passthrough | reencrypt
    insecureEdgeTerminationPolicy: Redirect
    wildcardPolicy: None

certManager:
  enabled: true
  issuerRef:
    kind: ClusterIssuer
    name: letsencrypt-prod    # uat em sqa
  dnsNames: []
  commonName: ""
  duration: 2160h       # 90d
  renewBefore: 360h     # 15d

image:
  repository: ""                       # gru.ocir.io/.../gateway
  tag: "2.9.4"
  pullSecret: ""                       # nome do pull secret em OCP
```

## Templates

| Arquivo | Renderização condicional |
|---|---|
| `templates/route.yaml` | `{{- if .Values.openshift.route.enabled }}` |
| `templates/certificate.yaml` | `{{- if .Values.certManager.enabled }}` |
| `templates/scc.yaml` | `{{- if .Values.openshift.scc.create }}` |
| `templates/image-pull-secret-job.yaml` | (opcional) Helm hook que lê OCI Vault via ExternalSecret |

## Templates existentes — ajustes

### `deployment.yaml`

- Não setar `runAsUser`/`runAsGroup` (SCC atribui UID random).
- Manter `readOnlyRootFilesystem: true`, `allowPrivilegeEscalation: false`,
  `capabilities.drop: ["ALL"]`, `seccompProfile.type: RuntimeDefault`.
- `image.repository` aceita OCIR URL completo.
- `imagePullSecrets` renderiza `{{ .Values.image.pullSecret }}` se setado.

### `service.yaml`, `serviceaccount.yaml`, `hpa.yaml`, `pdb.yaml`, `servicemonitor.yaml`, `networkpolicy.yaml`

Templates padrão K8s, compatíveis com OpenShift sem mudança estrutural.

## Labels padrão

```
app.kubernetes.io/name: gateway
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/version: {{ .Chart.AppVersion }}
app.kubernetes.io/component: api-gateway
app.kubernetes.io/part-of: revenu-platform
app.kubernetes.io/managed-by: Helm
platform.revenu/track: basa
platform.revenu/env: {{ .Values.krakend.env }}
platform.revenu/iso27001: "true"
```

## Pull secrets

Imagem pull de OCIR exige `dockerconfigjson` secret. Fluxo:

1. **Terraform / OCIR** gera token CI temporário (Fase 02).
2. **External Secrets Operator** sincroniza de OCI Vault → Secret K8s
   `ocir-pull` no namespace `gateway-{env}`.
3. **Helm chart** referencia `imagePullSecrets: [ name: ocir-pull ]`
   quando `image.pullSecret: ocir-pull`.

Alternativa: criar **Project-level pull secret** via `oc secrets link
default ocir-pull --for=pull` (fora do chart; runbook).

## Como renderizar

```
helm template gateway k8s/helm/gateway \
  -f k8s/helm/gateway/values-oci-sqa.yaml \
  -n gateway-sqa
```

## Validação

CI (Fase 06) valida via:

```
helm lint k8s/helm/gateway
helm template gateway k8s/helm/gateway -f k8s/helm/gateway/values-oci-sqa.yaml | kubeval --strict
helm template gateway k8s/helm/gateway -f k8s/helm/gateway/values-oci-pro.yaml | kubeconform -strict -schema-location default
```

## Checklist pronto-para-código

- [ ] Blocos `openshift` / `certManager` presentes em `values.yaml`.
- [ ] Templates `route.yaml` / `certificate.yaml` / `scc.yaml` (se
      `scc.create: true`) criados.
- [ ] `values-oci-{sqa,uat,pro}.yaml` compostos (ver
      `values-per-env.md`).
- [ ] `helm lint` passa.
- [ ] `helm template` renderiza Route + Certificate + Deployment sem
      `runAsUser` fixo.

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
