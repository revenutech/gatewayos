# ADR-004 — Red Hat ACS (StackRox) como opcional

**Arquiteto Principal:** Gustavo Armoa

- **Status:** Aceito — **opcional, não bloqueante** para v1 do track Basa
- **Data:** 2026-04-17
- **Decisores:** Platform Owner, Security Lead
- **Relacionado:** ADR-002, stack-reference.md §10

## Contexto

**Red Hat Advanced Cluster Security (ACS), baseado em StackRox**, provê:

- Admission controller (policy as code para imagens, deployments).
- Vulnerability management (integra com Clair / Trivy).
- Runtime detection (anomalias em processos, rede).
- Compliance profiles (CIS Kubernetes / OpenShift, NIST, PCI).
- Network segmentation simulator (recomenda NetworkPolicies).

A baseline de segurança do Gateway já inclui Trivy no CI, NetworkPolicy
manual por namespace e ausência de admission controller cluster-wide.

## Opções consideradas

1. **Adotar ACS desde a v1 do Basa** — cobertura RH "completa".
2. **Não adotar** — manter Trivy + NetworkPolicy manual + Sigstore
   policy-controller opcional como admission leve.
3. **Adotar como opcional / Fase futura** — documentar caminho, mas não
   bloquear v1.

| Critério | Adotar v1 | Não adotar | Opcional |
|---|---|---|---|
| Cobertura de controles ISO | 🟢 melhora A.8.9, A.8.16, A.8.22 | 🟡 | 🟢 |
| Esforço operacional | 🔴 alto (tunar policies) | 🟢 | 🟢 |
| Custo licença ACS | 🔴 subscription adicional | 🟢 | 🟢 |
| Risco de bloqueio de deploy | 🟡 policies podem bloquear pipelines | 🟢 | 🟢 |
| Valor sobre Trivy apenas | 🟢 runtime + admission | 🟡 | 🟢 |

## Decisão

**Não adotar ACS na v1 do track Basa.** Manter a baseline: Trivy no CI +
NetworkPolicy manual + Sigstore policy-controller (opcional) como admission.

**Documentar plano de adoção futura** em `05-security-supplychain/red-hat-acs-stackrox.md`,
com policies-alvo, custo e gatilhos para ativar.

## Justificativa

1. **Custo / complexidade** — ACS exige operação dedicada (tunar policies
   para não bloquear workloads legítimos). Não há bandwidth garantido para
   assumir esse eixo operacional na v1.
2. **Valor marginal sobre Trivy** — para gateway stateless sem dados
   sensíveis locais, o ganho de runtime detection é menor que em workloads
   stateful/críticos.
3. **Reversibilidade** — adotar ACS depois é fácil (operator install +
   aplicar CRs); desfazer policies que bloquearam deploys é caro.

## Consequências

### Positivas
- V1 do Basa entrega controles ISO sem inflar escopo.
- Time não precisa dominar StackRox antes de primeiro deploy.
- Decisão reversível — operator disponível no OperatorHub quando desejado.

### Negativas
- Sem runtime detection — detecção de comportamento anômalo dependerá de
  logs + Prometheus alerts, que são reativos.
- Sem admission controller rico — risco de imagem/deploy não-conforme
  passar (Trivy só bloqueia CI, não cluster).
- Compliance ISO marginalmente mais fraco para A.8.16 (monitoring
  activities) e A.8.22 (segregation of networks).

## Mitigações (obrigatórias mesmo sem ACS)

- **Trivy no CI** bloqueia CRITICAL/HIGH antes do push.
- **Sigstore policy-controller** opcional como admission leve (apenas
  verifica assinatura Cosign). Documentar em 05.
- **NetworkPolicy exhaustiva** por namespace (ingress e egress explícitos).
- **OpenShift Compliance Operator** gera relatórios CIS — cobre boa parte
  do que ACS faz em compliance profiles. Documentar em 07.

## Gatilhos para reavaliar

- Incidente em que runtime detection teria evitado dano.
- Requerimento regulatório novo (ex: SOC 2 Type II com exigência de
  runtime monitoring).
- Escopo do Basa crescer para módulos stateful (LedgerOS, Paymentos).

## Notas de implementação futura (referência)

Se/quando adotar:

1. Instalar `rhacs-operator` via OperatorHub em namespace `stackrox`.
2. Central (UI + API) em namespace dedicado `stackrox-central`.
3. Secured Cluster instalado em cada cluster OpenShift do Basa.
4. Policies iniciais — importar CIS OpenShift Profile + custom policies:
   - "Sem imagem não assinada" (Cosign sig check).
   - "Sem `privileged: true`".
   - "Sem egress para 0.0.0.0/0" exceto namespaces allowlist.
5. Rollout em `warn` mode por 30 dias antes de `enforce`.

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
