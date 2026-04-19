# Fase 00 — Foundation

**Arquiteto Principal:** Gustavo Armoa

Fundação do track Basa: define escopo, referência de stack
OCI/OpenShift/RH, decisões arquiteturais (ADRs) e convenções de
nomenclatura. Nenhuma fase posterior deve introduzir premissas novas sem
registrar aqui.

## Arquivos

| Documento | Finalidade |
|---|---|
| [scope.md](scope.md) | Objetivo, escopo in/out, premissas, stakeholders, riscos macro |
| [environments-plan.md](environments-plan.md) | Plano macro dos 3 envs (sqa / uat / pro) — propósito, sizing, security posture, gates, custos, cronograma |
| [stack-reference.md](stack-reference.md) | Mapa de referência OCI/OpenShift/RH (camada a camada) |
| [naming-conventions.md](naming-conventions.md) | Naming de recursos, tags, labels, namespaces |
| [adr-001-openshift-vs-oke.md](adr-001-openshift-vs-oke.md) | Escolha: OpenShift on OCI vs OKE + operators RH |
| [adr-002-registry-ocir-vs-quay.md](adr-002-registry-ocir-vs-quay.md) | Escolha: OCIR vs Quay.io como registry primário |
| [adr-003-tls-certmanager-vs-service-ca.md](adr-003-tls-certmanager-vs-service-ca.md) | Estratégia TLS: cert-manager (externo) + service-ca (interno) |
| [adr-004-red-hat-acs-opcional.md](adr-004-red-hat-acs-opcional.md) | Red Hat ACS (StackRox) como opcional, não bloqueante |
| [EMAIL-ENTREGA-BASA.md](EMAIL-ENTREGA-BASA.md) | E-mail formal de entrega ao BASA com delimitação de responsabilidade (trilha de auditoria) |

## Checklist de fechamento da Fase 00

- [ ] Escopo aprovado por Platform Owner e ISO Lead.
- [ ] Stack reference revisada — cobre todas as camadas relevantes.
- [ ] ADRs 001–004 aprovados ou explicitamente adiados.
- [ ] Naming conventions validados com time de Platform.
- [ ] Referências ISO (Cl. 4.3 Escopo, 6.1 Risco) confirmadas.

## Controles ISO 27001 tocados nesta fase

- Cl. 4.3 — Determinação do escopo do ISMS.
- Cl. 6.1.2 — Avaliação de risco (riscos macro listados em `scope.md`).
- A.5.8 — Information security in project management.
- A.5.37 — Documented operating procedures (fundamento para runbooks).

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
