# ADR-003 — TLS: cert-manager (externo) + service-ca (interno)

**Arquiteto Principal:** Gustavo Armoa

- **Status:** Aceito
- **Data:** 2026-04-17
- **Decisores:** Platform Owner, SRE Lead, Security Lead
- **Relacionado:** ADR-001, stack-reference.md §5

## Contexto

O Gateway precisa de TLS em dois planos: externo (Route público
`gateway.{env}.oci.allenty.io`) e interno (comunicação serviço↔serviço
intra-cluster). No OpenShift on OCI existem três caminhos:

1. **cert-manager + Let's Encrypt** (DNS01 via OCI DNS) — Operator padrão
   Kubernetes, emite certificados ACME automaticamente, renova, rotaciona.
2. **service-ca** (OpenShift built-in) — CA interna gerenciada pelo
   OpenShift Service CA Operator, assina automaticamente certs para
   serviços intra-cluster via annotation.
3. **Certs manuais** (OCI Certificate Authority ou upload manual) — cert
   comprado/emitido fora e injetado como Secret. Fora do escopo por exigir
   rotação manual, contrariando o critério de zero-config após setup.

## Opções consideradas

| Critério | cert-manager + LE | service-ca | Manual |
|---|---|---|---|
| TLS público (gateway.oci.allenty.io) | 🟢 | ❌ | 🟡 |
| TLS interno (serviço↔serviço) | 🟡 possível | 🟢 nativo | 🟡 |
| Renovação automática | 🟢 | 🟢 | ❌ |
| Integração OCI DNS | 🟢 via webhook/DNS01 | N/A | N/A |
| Zero-config após setup | 🟢 | 🟢 | ❌ |
| Compliance ISO A.8.24 (cryptography) | 🟢 | 🟢 | 🟡 |
| Rate limits | 🟡 LE: 50 certs/semana/domínio | N/A | N/A |

## Decisão

Usar **ambos, com papéis distintos**:

- **cert-manager + Let's Encrypt (DNS01 via OCI DNS)** — para TLS
  **externo** do Route público (`gateway.{env}.oci.allenty.io`).
- **service-ca (OpenShift built-in)** — para certificados **internos**
  (ServiceMonitor scrape sobre HTTPS, webhook admission controllers,
  comunicação intra-cluster).

Certs manuais **somente** como quebra-vidro (runbook em Fase 08).

## Justificativa

1. **Externo ≠ interno** — LE é ideal para certs públicos auto-renovados;
   service-ca é ideal para CA privada intra-cluster com rotação automática.
2. **Sem acoplar ACME a fluxo interno** — rate-limits do LE não afetam
   workloads internos.
3. **OpenShift já provisiona service-ca** — custo zero para habilitar.
4. **cert-manager é padrão de mercado** — documentação vasta, operadores
   maduros, webhook OCI DNS disponível (`cert-manager-webhook-oci`).
5. **ISO A.8.24 (Use of cryptography)** — dois mecanismos cobrem todos
   os planos (DMZ pública + comunicação interna autenticada).

## Consequências

### Positivas
- TLS externo auto-renovado via Let's Encrypt + cert-manager para
  intra-cluster.
- Rotação automática documentada e auditável.
- Compliance — evidências prontas para A.8.24.

### Negativas
- Duas ferramentas para operar (cert-manager + service-ca) em vez de uma.
- cert-manager-webhook-oci é mantido pela comunidade — avaliar pin de
  versão e fallback.
- Dependência de OCI DNS API para DNS01 challenges.

## Notas de implementação (Fase 03)

### Externo — cert-manager

- Instalar via Helm oficial (`jetstack/cert-manager`) ou OperatorHub
  (`cert-manager Operator for Red Hat OpenShift` — recomendado, supported).
- `ClusterIssuer` `letsencrypt-prod` com DNS01 solver apontando para OCI DNS:
  ```yaml
  solvers:
    - dns01:
        webhook:
          groupName: acme.webhook.oci
          solverName: oci
          config:
            useInstancePrincipal: true
            zoneName: "oci.allenty.io"
  ```
- Gateway Route referencia `Certificate` CR emitido por esse issuer.
- Usar `ClusterIssuer` staging (`letsencrypt-staging`) em sqa para evitar
  rate limits.

### Interno — service-ca

- Annotation no `Service` do Gateway (quando for preciso HTTPS interno):
  ```yaml
  service.beta.openshift.io/serving-cert-secret-name: gateway-serving-cert
  ```
- OpenShift injeta automaticamente `Secret` `gateway-serving-cert` com
  cert + key assinados pela service-ca.
- Clientes intra-cluster confiam na CA via `service-ca.crt` injetado via
  `ConfigMap` annotation `service.beta.openshift.io/inject-cabundle: "true"`.

### Rotação

- cert-manager: automática, 30 dias antes do vencimento (configurável).
- service-ca: automática, rotaciona serving cert a cada 1 ano; CA rotaciona
  a cada ~26 meses.

## Revisão

Reavaliar se:
- cert-manager-webhook-oci for descontinuado (→ fallback para HTTP01 com
  LB OCI ou migrar para OCI Certificate Service).
- Entrar ACS Admission Controller com mTLS service mesh (→ avaliar Istio
  ou OpenShift Service Mesh, o que muda o desenho interno).

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
