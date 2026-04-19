# FIPS Mode — Fase 05 Cross-reference

**Arquiteto Principal:** Gustavo Armoa

## Objetivo

Consolidar a postura FIPS do track Basa — decisão, camadas envolvidas e
checklist de ativação. Este documento agrega as referências já presentes
em outras fases sem duplicar conteúdo.

## Decisão

**V1 — FIPS DESLIGADO (FIPS-ready).**

Detalhes em:
- [Fase 01 — fips-readiness.md](../01-docker-ubi/fips-readiness.md) — build
  go-boringcrypto, verificação, libs dependentes.
- [Fase 02 — module-openshift.md](../02-iac-terraform-oci/module-openshift.md)
  — flag `fips_enabled` no install-config.

## Camadas FIPS (resumo)

| Camada | Artefato/Config | Estado v1 | Como ligar |
|---|---|---|---|
| **Imagem base** | UBI9-minimal | ✅ FIPS-capable | Auto — UBI OpenSSL valida FIPS quando RHCOS em FIPS mode |
| **Binário KrakenD** | Go build | 🟡 modo normal | `GOEXPERIMENT=boringcrypto CGO_ENABLED=1 go build` |
| **RHCOS (nodes)** | `install-config.yaml` | 🔴 off | `fips: true` no install-config — **irreversível** |
| **Cluster OCP control plane** | Herdado do RHCOS | 🔴 off | auto se RHCOS FIPS |
| **Operators** (cert-manager, OTel, Logging, ACS, Compliance) | Verificar cada | 🟡 | Consultar doc do operator; maioria já é FIPS-compat |
| **Vault (OCI KMS)** | `protection_mode` | 🟢 HSM | já FIPS 140-2 L3 em uat/pro |
| **TLS Routes** | cert-manager + RSA2048 | 🟢 | compat FIPS |

## Cenários suportados v1

1. **Modo normal** (default): runtime não-FIPS. Build de imagem poderia
   ser FIPS-ready (boringcrypto) mas sem nó FIPS para aproveitar.
2. **Modo parcial sqa**: cluster OCP não-FIPS + imagem FIPS-ready — útil
   para testes locais antes de criar cluster FIPS.

## Cenário v2 (quando exigido)

**Cluster OCP novo instalado com `fips: true`** + imagem buildada com
`GOEXPERIMENT=boringcrypto` + operators declarados FIPS-compat.

### Checklist de ativação FIPS (para v2)

- [ ] Aprovação formal do requisito (ticket com cliente / regulador).
- [ ] ADR novo em `00-foundation/` documentando gatilho.
- [ ] Criar cluster OCP novo (não convertível).
  - `install-config.yaml` com `fips: true`.
  - Validação pós-install: `oc debug node/<any> -- chroot /host cat /proc/sys/crypto/fips_enabled` → `1`.
- [ ] Atualizar Dockerfile.ubi9:
  - Build com `GOEXPERIMENT=boringcrypto CGO_ENABLED=1 go build`.
  - Validação: `go tool nm krakend | grep -i boring` retorna símbolos.
- [ ] Verificar cada operator:
  - cert-manager Operator for Red Hat OpenShift — FIPS support em versões recentes; verificar changelog.
  - OpenShift Logging (Vector) — ✅ nas versões supported.
  - OpenTelemetry Operator (RH build) — ✅.
  - Grafana Operator — operator em si ok; Grafana binary requer check.
  - Loki Operator — ✅.
  - ACS — ✅ (quando/se adotado).
- [ ] Publicar tag imagem `-fips` (ex: `v1.0.0-fips`).
- [ ] Ingerir CVE Red Hat FIPS module em ciclo de Trivy.
- [ ] Runbook (Fase 08) — troubleshooting pods quebrando em FIPS mode.

## Ligações que NÃO funcionam em FIPS

Se FIPS ligado e algum consumidor usa:

- **MD5** (hashing) — bloqueado.
- **SHA-1 para assinatura** — bloqueado.
- **3DES** — bloqueado.
- **RSA <2048 bits** — bloqueado.
- **SSH DSA keys** — bloqueado.

Gateway atual não usa nenhum desses. **Libs de deps** (verificar cada):
- `go-jose` — usa SHA-256+; ✅.
- `mux` / stdlib `net/http` — TLS 1.2+ RSA2048+, ✅.
- `lua-lru-cache` (plugin) — caching in-memory, sem crypto.

## Monitoring de violações

Em cluster FIPS, OpenShift emite eventos se um pod tentar crypto
não-FIPS. Alerta PrometheusRule:

```
alert: FIPSModeViolation
expr: increase(node_fips_crypto_violations_total[5m]) > 0
for: 0m
labels:
  severity: critical
annotations:
  summary: "Pod tentando crypto não-FIPS no cluster {{ $labels.cluster }}"
```

## Evidências para auditoria (A.8.24)

1. Output `cat /proc/sys/crypto/fips_enabled` em um node.
2. Build log mostrando `GOEXPERIMENT=boringcrypto`.
3. SHA256 do binário FIPS assinado e registrado em Rekor.
4. Cert FIPS 140-2 L3 do OCI Vault (Oracle publica).
5. Declarations of conformance dos operators usados.

## Decisões de design

1. **V1 sem FIPS** — sem requisito real + complexidade operacional alta.
2. **FIPS-ready no build** (validar `boringcrypto` funciona em CI, tag opcional).
3. **Novo cluster dedicado** se ligar — sem conversão.
4. **Vault pro sempre HSM** — 1 camada FIPS mesmo em v1.
5. **Documento vivo** — atualizar quando operators ganharem/perderem FIPS.

## Checklist v1 (FIPS-ready only)

- [ ] Build com `boringcrypto` validado localmente (Dockerfile.ubi9 step opcional).
- [ ] Tag `-fips` produzida (sem push) em CI como dry-run trimestral.
- [ ] Doc de operators FIPS-compat mantida aqui.
- [ ] Vault uat+pro em modo HSM (já coberto em Fase 02).
- [ ] Decision para ativar FIPS revisada anualmente na Management
      Review (A.9.3).

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
