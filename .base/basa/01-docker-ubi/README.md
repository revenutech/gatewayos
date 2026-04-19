# Fase 01 — Docker UBI

**Arquiteto Principal:** Gustavo Armoa

Especificação da imagem de container do Gateway para o track Basa, usando
**Red Hat Universal Base Image 9 (UBI9-minimal)** como runtime, com o
binário KrakenD CE 2.9.4 patchado (CVE-2026-34986).

## Arquivos

| Documento | Finalidade |
|---|---|
| [dockerfile-strategy.md](dockerfile-strategy.md) | Multi-stage, stages, user non-root, entrypoint |
| [krakend-build-on-ubi.md](krakend-build-on-ubi.md) | Compilar KrakenD + patch go-jose em toolchain RH |
| [fips-readiness.md](fips-readiness.md) | Modo FIPS, Go FIPS, boringcrypto / OpenShift FIPS mode |
| [rh-container-certification.md](rh-container-certification.md) | Labels, licenses e checklist Red Hat Container Certification |

## Checklist de fechamento da Fase 01

- [ ] `Dockerfile.ubi9` documentado e valida manualmente com `docker build`.
- [ ] Build do KrakenD patchado funciona com toolchain Go UBI (ou go-toolset).
- [ ] Imagem roda como UID aleatório (padrão OpenShift) sem quebrar.
- [ ] FIPS readiness avaliado — decisão documentada.
- [ ] Labels de RH Container Certification presentes.
- [ ] Trivy scan da imagem UBI sem CVEs CRITICAL/HIGH não-tratados.

## Controles ISO 27001 tocados

- A.8.8 — Management of technical vulnerabilities (patch go-jose).
- A.8.9 — Configuration management (imagem reprodutível, tags imutáveis).
- A.8.19 — Installation of software on operational systems.
- A.8.24 — Use of cryptography (FIPS mode readiness).
- A.5.23 — Information security for use of cloud services (base image chain of trust).

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
