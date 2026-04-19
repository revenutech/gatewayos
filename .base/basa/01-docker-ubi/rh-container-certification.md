# Red Hat Container Certification

**Arquiteto Principal:** Gustavo Armoa

## Objetivo

Deixar a imagem do Gateway (track Basa) pronta para obter **Red Hat
Container Certification** e ser listada no **Red Hat Ecosystem Catalog**.

Certificação é **opcional** mas barata uma vez que a imagem é UBI-based —
basta adicionar metadata exigida e rodar o `preflight` tool.

## Benefícios da certificação

1. **Selo "Red Hat Certified"** — sinal para clientes corporativos.
2. **Rede de confiança Red Hat** — auditoria / vulnerability feed reconhecida.
3. **Prontidão comercial** — pré-requisito caso queiramos ofertar Gateway
   como partner offering no Red Hat Marketplace.
4. **Evidência ISO 27001** — A.5.23 (cloud services) reforçado.

## Requisitos (resumo)

1. Imagem baseada em **UBI** (qualquer variant) — ✅ UBI9-minimal.
2. Labels obrigatórios (ver abaixo).
3. Licença: arquivo `/licenses/LICENSE` na imagem com a licença (Apache-2.0).
4. `microdnf clean all` — sem cache de package manager.
5. Usuário não-root (UID ≥ 1001 preferível; ou root group-0 pattern).
6. Sem capabilities Linux extras.
7. Aprovação no `preflight` tool (CLI Red Hat).
8. Healthcheck presente.
9. Sem vulnerabilidades CRITICAL/HIGH não-fixáveis (use `.trivyignore` documentado).

## Labels obrigatórios

```dockerfile
LABEL name="revenu-platform/gateway" \
      vendor="Revenu" \
      version="2.9.4-basa" \
      release="1" \
      summary="Revenu Platform API Gateway (KrakenD CE 2.9.4, UBI9)" \
      description="API Gateway for the Revenu Platform. Handles JWT, rate limiting, circuit breaking, CORS." \
      maintainer="platform@revenu.com.br" \
      url="https://github.com/revenutech/revenu-platform" \
      license="Apache-2.0" \
      io.k8s.display-name="Revenu Gateway" \
      io.k8s.description="Revenu Platform API Gateway for OCI/OpenShift" \
      io.openshift.tags="api-gateway,krakend,revenu,gateway" \
      io.openshift.expose-services="8080:http,8090:metrics"
```

Campos **obrigatórios pela Red Hat**: `name`, `vendor`, `version`,
`release`, `summary`, `description`.

Campo `release` deve ser um inteiro incrementado a cada rebuild da mesma
`version` (ex: `2.9.4-basa`/`release=1`, `2.9.4-basa`/`release=2`).

## Arquivo de licença

No repo:

```
LICENSE        # já existente — Apache-2.0
```

No Dockerfile.ubi9:

```dockerfile
COPY LICENSE /licenses/LICENSE
```

Red Hat exige `/licenses/` como diretório (não arquivo).

## `preflight` — validação Red Hat

Red Hat fornece o CLI `preflight` ([github.com/redhat-openshift-ecosystem/openshift-preflight](https://github.com/redhat-openshift-ecosystem/openshift-preflight))
que valida todos os requisitos antes de submeter.

Execução em CI (Fase 06):

```
preflight check container \
  gru.ocir.io/revenutech/gateway-basa-uat/gateway:2.9.4-basa \
  --docker-config=$HOME/.docker/config.json
```

Saída: `PASSED` / `FAILED` por check (14 checks obrigatórios + 5 opcionais).

## Checks do `preflight` (mapeamento)

| Check | Atendido por |
|---|---|
| HasLicense | `LICENSE` copiado em `/licenses/` |
| HasUniqueTag | tag não `latest` + immutability em OCIR (pro) |
| LayerCountAcceptable | Multi-stage produz ~5 layers |
| HasNoProhibitedPackages | UBI-minimal não traz pacotes banidos |
| HasRequiredLabel | Labels acima |
| RunsAsNonRoot | `USER 1001` |
| HasModifiedFiles | (opcional) |
| BasedOnUbi | ubi9/ubi-minimal ✅ |
| HasMinimalVulnerabilities | Trivy CI + `.trivyignore` para CVEs aceitos |

## Submissão ao Red Hat Ecosystem Catalog (opcional)

1. Criar conta em `connect.redhat.com` como parceiro.
2. Registrar produto "Revenu Gateway".
3. Publicar imagem com `release` taggeado (não mexer depois).
4. Preencher metadados (descrição, suporte, CVE policy).
5. Red Hat valida (tipicamente 5–10 dias úteis).

## Decisão na v1

**Prontidão completa** (imagem cumpre todos os requisitos). **Submissão
fica opcional** — ativar quando houver valor comercial.

## Checklist de fechamento

- [ ] Todos os labels obrigatórios presentes no Dockerfile.ubi9.
- [ ] `/licenses/LICENSE` copiado na imagem.
- [ ] `microdnf clean all` após cada install.
- [ ] Usuário não-root confirmado.
- [ ] `preflight check container` passa localmente.
- [ ] CI inclui step opcional de `preflight` (Fase 06).
- [ ] Decisão de submeter ou não ao catalog — registrada em project memory
      ou ADR extra.

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
