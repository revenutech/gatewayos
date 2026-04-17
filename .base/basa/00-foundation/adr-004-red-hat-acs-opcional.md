# ADR-004 — Red Hat ACS (StackRox) como opcional

- **Status:** Aceito — **opcional, não bloqueante** para v1 do track Basa
- **Data:** 2026-04-17
- **Decisores:** Platform Owner, Security Lead
- **Relacionado:** ADR-002, equivalence-matrix.md §10

## Contexto

**Red Hat Advanced Cluster Security (ACS), baseado em StackRox**, provê:

- Admission controller (policy as code para imagens, deployments).
- Vulnerability management (integra com Clair / Trivy).
- Runtime detection (anomalias em processos, rede).
- Compliance profiles (CIS Kubernetes / OpenShift, NIST, PCI).
- Network segmentation simulator (recomenda NetworkPolicies).

O track GCP hoje **não usa** ACS — o controle equivalente é Trivy no CI,
NetworkPolicy manual e ausência de admission controller.

## Opções consideradas

1. **Adotar ACS desde a v1 do Basa** — paridade com plano RH "completo".
2. **Não adotar** — manter Trivy + NetworkPolicy manual, igual ao GCP.
3. **Adotar como opcional / Fase futura** — documentar caminho, mas não
   bloquear v1.

| Critério | Adotar v1 | Não adotar | Opcional |
|---|---|---|---|
| Paridade com GCP | 🟡 supera (não é equivalente) | 🟢 | 🟢 |
| Cobertura de controles ISO | 🟢 melhora A.8.9, A.8.16, A.8.22 | 🟡 | 🟢 |
| Esforço operacional | 🔴 alto (tunar policies) | 🟢 | 🟢 |
| Custo licença ACS | 🔴 subscription adicional | 🟢 | 🟢 |
| Risco de bloqueio de deploy | 🟡 policies podem bloquear pipelines | 🟢 | 🟢 |
| Valor sobre Trivy apenas | 🟢 runtime + admission | 🟡 | 🟢 |

## Decisão

**Não adotar ACS na v1 do track Basa.** Manter paridade com GCP:
Trivy no CI + NetworkPolicy manual + Sigstore policy-controller (opcional)
como admission.

**Documentar plano de adoção futura** em `05-security-supplychain/red-hat-acs-stackrox.md`,
com policies-alvo, custo e gatilhos para ativar.

## Justificativa

1. **Paridade com GCP** — introduzir ACS no Basa cria divergência funcional
   entre tracks (controles disponíveis em OCI, não em GCP). Para "gêmeo", é
   desejável similaridade.
2. **Custo / complexidade** — ACS exige operação dedicada (tunar policies
   para não bloquear workloads legítimos). Não há bandwidth garantido.
3. **Valor marginal sobre Trivy** — para gateway stateless sem dados
   sensíveis locais, o ganho de runtime detection é menor que em workloads
   stateful/críticos.
4. **Reversibilidade** — adotar ACS depois é fácil (operator install +
   aplicar CRs); desfazer policies que bloquearam deploys é caro.

## Consequências

### Positivas
- V1 do Basa entrega paridade sem inflar escopo.
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

- **Trivy no CI** bloqueia CRITICAL/HIGH antes do push (já padrão).
- **Sigstore policy-controller** opcional como admission leve (apenas
  verifica assinatura Cosign). Documentar em 05.
- **NetworkPolicy exhaustiva** por namespace (ingress e egress explícitos).
- **OpenShift Compliance Operator** gera relatórios CIS — cobre boa parte
  do que ACS faz em compliance profiles. Documentar em 07.

## Gatilhos para reavaliar

- Incidente em que runtime detection teria evitado dano.
- Requerimento regulatório novo (ex: SOC 2 Type II com exigência de
  runtime monitoring).
- Adoção de ACS no track GCP → reavaliar paridade.
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
