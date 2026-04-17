# ADR-002 — Container Registry: OCIR vs Quay.io

- **Status:** Aceito
- **Data:** 2026-04-17
- **Decisores:** Platform Owner, Security Lead
- **Relacionado:** ADR-004, equivalence-matrix.md §3

## Contexto

O track Basa precisa de um container registry para a imagem do Gateway
assinada, escaneada e com retenção controlada. Duas opções naturais no
ecossistema OCI + Red Hat:

1. **OCI Container Registry (OCIR)** — registry nativo da OCI, regional,
   integrado com IAM OCI, pull via Image Pull Secret ou Instance Principal.
2. **Quay.io (hosted) ou Red Hat Quay (self-hosted)** — registry Red Hat com
   integração nativa a OpenShift, ACS, vulnerability scanning (Clair),
   Cosign, notificações.

## Opções consideradas

| Critério | OCIR | Quay.io (hosted) | Red Hat Quay (self-hosted) |
|---|---|---|---|
| Latência pull da OCI | 🟢 Intra-região | 🟡 Internet | 🟡 depende onde hospedar |
| Custo storage | Pago por GB | Plano grátis + pago | Subscription RH + compute |
| Integração OCP | 🟡 Pull secret manual | 🟢 Nativa | 🟢 Nativa |
| Scan vulnerabilidades | 🟡 básico | 🟢 Clair nativo | 🟢 Clair nativo |
| Cosign signing | 🟢 compatível (OCI standard) | 🟢 compatível | 🟢 compatível |
| Imutabilidade de tag | 🟢 retention rules | 🟢 | 🟢 |
| IAM | OCI IAM | Red Hat SSO | Red Hat SSO |
| Compliance ISO (dados EU/BR) | 🟢 controla região | 🟡 hosted em região RH | 🟢 self-hosted |
| Complexidade operacional | Baixa (gerenciado) | Baixa (SaaS) | Alta (operar Quay) |
| Lock-in | Médio (OCI) | Alto (SaaS RH) | Baixo |

## Decisão

**Adotar OCIR como registry primário** do track Basa.

**Cosign + Trivy** continuam sendo o controle de supply chain primário (mesmo
padrão do track GCP), rodando sobre OCIR — o registry em si fica neutro.

**Red Hat Quay** fica documentado como opção para um segundo momento, caso
exijamos: (a) Clair scanning nativo integrado a OCP, (b) sign policy mais
rica, (c) geo-replication entre clouds.

## Justificativa

1. **Latência e custo de egress** — OCIR intra-região para cluster OpenShift
   na mesma região OCI minimiza custo e latência de pull.
2. **Paridade com track GCP** — GCP usa Artifact Registry (registry do
   próprio cloud). Manter simetria em OCI.
3. **Controle de dados** — OCIR sob tenancy OCI em `sa-saopaulo-1` atende
   requisito de residência de dados (B-R01 do risk register).
4. **Cosign é registry-agnóstico** — segurança de supply chain independe
   do registry escolhido.
5. **Operacional simples** — não assumir overhead de operar Quay self-hosted
   sem benefício claro.

## Consequências

### Positivas
- Build → push → pull todo na mesma região OCI (menor custo + latência).
- Sem introdução de novo provider SaaS (não vira item do risk register).
- IAM unificado com resto da infra OCI.

### Negativas
- Scanning nativo OCIR é menos profundo que Clair (Quay) — mitigado por
  Trivy no pipeline (já padrão GCP).
- Admission policy (Sigstore policy-controller) precisa ser instalada
  separadamente (não é nativo OCIR); documentado em Fase 05.
- Se ACS for adotado (ADR-004), parte da sinergia Quay↔ACS se perde.

## Notas de implementação (Fase 02 + 05 + 06)

- **Um repo por env**: `gateway-basa-dev`, `gateway-basa-staging`, `gateway-basa-prod`.
- **Retention rules**:
  - dev: keep last 10 tags.
  - staging: keep last 20 tags + todos `v*.*.*-rc*`.
  - prod: keep all `v*.*.*` tags (imutáveis) + last 30 outras tags.
- **Tag immutability** — ativada em prod, desativada em dev.
- **Auth CI** — via OIDC Federation (Fase 06) usando `docker login` com
  token curto obtido de `oci iam` + chave de sessão.
- **Auth pull em OpenShift** — Image Pull Secret gerenciado pelo operator
  de secrets (External Secrets Operator lendo de OCI Vault).
- **URL padrão**: `{region-code}.ocir.io/{tenancy}/gateway-basa-{env}/gateway:{tag}`
  (ex: `gru.ocir.io/revenutech/gateway-basa-dev/gateway:dev-abc123`).

## Revisão

Reavaliar se:
- ACS (ADR-004) for adotado e integração com Quay trouxer ganho claro.
- Precisar de geo-replication entre clouds (migrar para Quay).
- OCIR impuser limitações de throughput / retention não mitigáveis.
