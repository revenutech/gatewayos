# Risk Register — OCI/OpenShift

Complementa `.base/docs/risk/risk-register.md`. Contém:

1. **Novos riscos (B-R01..B-R04)** — exclusivos do track Basa.
2. **Revisão dos riscos existentes (R01..R18)** — impacto da
   implementação OCI/OpenShift em cada um.
3. **Treatment plan** específico para novos riscos.

Metodologia segue `.base/docs/risk/risk-methodology.md` — escalas de
likelihood (L) 1–5 e impact (I) 1–5; score = L × I; níveis
(Low ≤4, Medium 5–9, High 10–14, Critical ≥15).

## Novos riscos — B-R01..B-R04

> IDs pré-alocados em Fase 00 `scope.md`. Esta tabela consolida.

| ID | Risk | Threat | Vulnerability | L | I | Score | Level | Treatment | Owner | Controls | Status |
|----|------|--------|---------------|:-:|:-:|:-----:|-------|-----------|-------|----------|--------|
| B-R01 | **Lock-in de região OCI** | Capacidade OpenShift limitada em `sa-saopaulo-1` impede expansão | Apenas uma região no escopo v1 | 3 | 4 | **12** | High | Mitigate | Platform Owner | A.5.29, A.8.14 | Partial |
| B-R02 | **Mudança de política UBI** | Red Hat altera licenciamento UBI tornando inviável | Dependência de UBI9-minimal como base | 2 | 4 | **8** | Medium | Accept + Monitor | Security Lead | A.5.22, A.8.30 | Monitored |
| B-R03 | **Cadência de upgrade OCP** | Self-managed control plane exige janelas manuais | Responsabilidade interna de upgrade vs produto managed | 3 | 3 | **9** | Medium | Mitigate | SRE Lead | A.8.8, A.8.32 | Partial |
| B-R04 | **OIDC GitHub → OCI** | Identity Domain IdP + JIT rules é produto mais recente, menos documentado | Acoplamento CI↔OCI via claim matching | 3 | 4 | **12** | High | Mitigate | Security Lead | A.5.16, A.8.5 | Partial |

## Treatment plan — novos

### B-R01 — Lock-in de região OCI

**Ações:**
1. Listar **regiões alternativas** com capacidade OCP disponível em
   `sa-*` (Vinhedo, potencialmente São Paulo outra AD).
2. **DR runbook** cross-region em Fase 08.
3. **Critério de cutover**: se `sa-saopaulo-1` ficar indisponível >4h,
   invocar DR plan.
4. **Capacity reservations** OCI para masters pro (evita falta de shape
   em pico).

**Evidência:** `08-runbooks/dr-failover-cross-region.md`, OCI capacity
reservations screenshot, Management Review quarterly capacity check.

### B-R02 — Mudança de política UBI

**Ações:**
1. **Monitor** Red Hat licensing mailing list + release notes.
2. **Alternativa pré-identificada**: imagem `registry.access.redhat.com/ubi9/ubi-minimal`
   (já em uso); fallback a `fedora-minimal` ou `distroless` se UBI mudar.
3. **Review semestral** no Management Review.

**Evidência:** monitoring subscription + ADR revision history.

### B-R03 — Cadência de upgrade OCP

**Ações:**
1. **Upgrade runbook** em Fase 08 com janela, pré/pós checks.
2. **uat sempre N versões atrás de OCP stable** — testa upgrade.
3. **Prod upgrade N+1 minor** — só após ≥30 dias em uat.
4. **Red Hat Insights** configurado para alertas de EOL.

**Evidência:** `08-runbooks/openshift-upgrade.md`, Insights screenshot,
CHANGELOG.

### B-R04 — OIDC GitHub → OCI

**Ações:**
1. **Documentação passo-a-passo** (Fase 06 `oci-oidc-federation.md`).
2. **PoC precoce** — primeiro PoC de OIDC antes de depender em deploy
   produção.
3. **Fallback** temporário: usar OCI Customer Secret Key com rotation
   30d via Vault se OIDC falhar (runbook break-glass).
4. **OCI Audit** monitora falhas de token exchange.

**Evidência:** workflow successful runs + Audit logs.

## Revisão de riscos existentes (R01..R18)

Cada risco do register principal avaliado em relação à implementação
Basa:

| ID | Risco | Continua válido em Basa? | Delta |
|---|---|:-:|---|
| R01 | JWT token theft/replay | ✅ | Mesmas mitigações (DPoP, revocation, bloom); evidência Basa = `partials/security/dpop.tmpl` + ESO Redis password |
| R02 | DDoS/volumetric | ✅ | Route → HAProxy Router (intrínseco HA) + rate-limiting KrakenD; opcional OCI WAF |
| R03 | Credential stuffing | ✅ | Mesmas Lua policies; OpenShift Monitoring detecta via PrometheusRule |
| R04 | Backend cascade | ✅ | Mesmos circuit breakers KrakenD; NetPol OVN-K limita blast radius |
| R05 | Config tampering | ✅ | CODEOWNERS + audit.sh + GitHub protection; compliance-oci.yml valida |
| R06 | TLS cert compromise | ✅ | cert-manager auto-rotate + service-ca + Vault HSM em pro |
| R07 | JWKS unavailability | ✅ | JWKS cache 1h + `failed_jwk_key_cooldown` (inalterado) |
| R08 | Cross-tenant leakage | ✅ | CEL tenant_id + Lua security policies (inalterado); NetPol reforça |
| R09 | Supply chain | ✅ | Cosign + SBOM attest + SLSA (Fase 05); status "Treated" |
| R10 | Sensitive data in logs | ✅ | Vector filter + sem PII em labels Prom (Fase 03/04) |
| R11 | Rate limit bypass | ✅ | Mesmas estratégias KrakenD |
| R12 | Zero-day KrakenD | ✅ | Mesmo monitoring; Trivy Red Hat OVAL provê feed adicional |
| R13 | Insider threat | ✅ | OCI Audit + GitHub audit + 2 reviewers pro |
| R14 | TLS downgrade | ✅ | HAProxy Router configurado TLS 1.2+ |
| R15 | Bloom FP | ✅ | inalterado |
| R16 | Redis SPOF | ✅ | **Mantém risco**; mitigação futura inclui Redis HA OCP (runbook) |
| R17 | Geo-blocking evasion | ✅ | Mesmas policies Lua |
| R18 | CVE-2026-34986 | ✅ | Mesmo patch go-jose em Dockerfile.ubi9 (reutiliza `patch-deps.sh`); status `Treated` |

## Riscos **invalidados** no Basa

Nenhum. Todos R01..R18 aplicáveis.

## Riscos **reduzidos** no Basa

- **R06 (cert compromise)** — Vault HSM em pro é L3; menor chance de key exposure via API.
- **R09 (supply chain)** — Cosign + attestation obrigatório + SLSA Level 3.
- **R13 (insider)** — OCI Audit + segregação via compartments.

## Novos vetores tratados

- **B-R01 (lock-in de região)** — DR cross-region planejado (Fase 08).
- **B-R04 (OIDC maturity)** — PoC precoce + fallback documentado.

## Revisão

- **Frequency:** semestral (mesma cadência do register principal).
- **Owner:** Security Lead (com input SRE Lead para B-R03).
- **Trigger extraordinário:**
  - Incidente materializando um risco → ad-hoc review.
  - Mudança de ADR (Fase 00) → review de riscos impactados.

## Heatmap

```
         L=1    L=2    L=3    L=4    L=5
I=5            R05 R06 R08 R09
I=4                    B-R01 B-R04  R01 R02
               R12 R18 B-R03
I=3                    R07 R10 R16
I=2                    R11 R17
I=1
```

(Atualizar quando novos riscos entrarem; manter em Management Review.)

## Checklist pronto-para-código

- [ ] 4 novos riscos B-R01..R04 aprovados.
- [ ] Revisão R01..R18 validada por Security Lead.
- [ ] Evidências de treatment apontando para fases concretas.
- [ ] Heatmap atualizado no Management Review.
- [ ] compliance-oci.yml verifica este arquivo existe (Fase 06).
