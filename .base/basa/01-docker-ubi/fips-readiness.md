# FIPS Readiness

**Arquiteto Principal:** Gustavo Armoa

## Objetivo

Avaliar, documentar e preparar (sem necessariamente ativar na v1) o caminho
para que o Gateway rode em **FIPS 140-2/3 mode** no track Basa, aproveitando
a base Red Hat (UBI9 + RHCOS).

## Decisão inicial (v1)

**FIPS disabled por padrão**, **FIPS-ready** por construção.

Motivos:
- Sem requerimento regulatório imediato (não somos contratados por
  gov/defesa).
- FIPS pode introduzir incompatibilidades com libs que usam criptografia
  não-validada (ex: algumas implementações JWT/JWE).
- Ganho marginal vs custo operacional (testes extras, certificação lib).

Re-avaliar se:
- Cliente/parceiro exigir compliance FIPS (muito comum em integração com
  instituições financeiras dos EUA).
- ISO 27001 audit recomendar como evidência forte de A.8.24.

## Camadas envolvidas

| Camada | Estado FIPS |
|---|---|
| **RHCOS** (nodes OpenShift) | Ativável no install-config (`fips: true`). Ligando, cluster inteiro opera em FIPS. |
| **Go runtime** (KrakenD) | Requer build com `GOEXPERIMENT=boringcrypto` + libc glibc (UBI ✅). |
| **UBI9 userland** | libs OpenSSL da Red Hat são FIPS-validadas (módulo certificado). |
| **KrakenD deps** | Precisa que go-jose, lura, mux, etc. usem `crypto/*` padrão do Go (não forks). |
| **OpenShift operators** (cert-manager, OTel, etc.) | Confirmar cada operator declara FIPS-compatibility — alguns não. |

## Se habilitar FIPS

### 1. Cluster OpenShift

No `install-config.yaml` (Fase 02):

```yaml
fips: true
```

**Não é reversível** — uma vez ligado, desligar exige reinstalar o cluster.

Efeito:
- RHCOS boot em FIPS mode (kernel crypto FIPS).
- `/proc/sys/crypto/fips_enabled` = 1 em todo node.
- OpenShift oculta imagens/workloads não-FIPS-compliant com warning.

### 2. Build do KrakenD

```
GOEXPERIMENT=boringcrypto \
CGO_ENABLED=1 \
go build -ldflags="-X ...Version=2.9.4-patched-fips" -o /build/krakend ./cmd/krakend-ce
```

Verificar:

```
go tool nm /build/krakend | grep -i boring   # deve aparecer símbolos _Cfunc_
```

### 3. Libs terceiras

Revisar cadeia de dependências:

- `github.com/go-jose/go-jose/v3 v3.0.5` — usa `crypto/*` do Go padrão. ✅
- `github.com/go-jose/go-jose/v4 v4.1.4` — idem. ✅
- **Lua scripts** (`krakend/partials/lua/`) — não fazem crypto sensível
  (apenas parsing). ✅
- **JWKS rotation** — usa `net/http` + Go crypto padrão. ✅

Risco: futuros plugins KrakenD custom que tragam forks ou CGo externo.

### 4. OpenShift ecosystem

| Componente | FIPS? | Referência |
|---|---|---|
| OpenShift control plane | ✅ | RH docs oficial |
| cert-manager Operator for OpenShift | ✅ quando flag FIPS ativa | RH docs |
| Prometheus Operator | ✅ | stock OCP |
| OpenShift Logging (Loki) | 🟡 verificar versão | varia |
| OpenTelemetry Operator (RH) | ✅ | RH docs |
| ACS (StackRox) | ✅ | RH docs |

## Caminho incremental

1. **v1** — Build FIPS-ready (Go boringcrypto), cluster NÃO em FIPS. Imagem
   roda em modo normal.
2. **Gatilho** — Requerimento externo ou decisão estratégica.
3. **v2** — Criar cluster OpenShift FIPS-only (ou converter via reinstall),
   publicar imagem com sufixo `-fips`.

## Evidências para ISO 27001 (A.8.24)

- Build log mostrando `GOEXPERIMENT=boringcrypto` ativo.
- SHA256 do binário FIPS registrado em attestation.
- Declaração assinada (statement of compliance) do fornecedor do UBI
  (Red Hat) e dos operators usados.
- Output `/proc/sys/crypto/fips_enabled` do cluster.

## Checklist FIPS-ready (v1)

- [ ] Documentar que FIPS está desligado na v1.
- [ ] Verificar se build com `GOEXPERIMENT=boringcrypto` **funciona**
      (smoke test local).
- [ ] Incluir tag `fips-ready` em imagens de QA (mesmo sem cluster FIPS).
- [ ] Adicionar `fips.enabled: false` em `values-oci-*.yaml` (Fase 03).
- [ ] Decisão registrada em ADR se for mudar.

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
