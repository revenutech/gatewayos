# Statement of Applicability (SoA) — OCI/OpenShift

Complementa `.base/docs/risk/statement-of-applicability.md`. Para cada
controle Annex A, declara aplicabilidade no track Basa e a justificativa.

> Legenda: ✅ aplicável e implementado · 🛠 aplicável, em implementação ·
> 📝 aplicável, documentado (não executado v1) · ➖ não aplicável.

## Resumo executivo

- **Aplicáveis no Basa:** 92 dos 93 controles Annex A (99%).
- **Não-aplicáveis:** 1 (A.7.9 Security of assets off-premises —
  laptops não armazenam material criptográfico prod).
- **Implementados ao final da Fase 06:** 85.
- **Documentados apenas (execução futura):** 7 — majoritariamente
  hardening opcional (ACS, FIPS, tracing).

## Matriz resumida

### A.5 — Organizational

| Controle | Aplica Basa? | Status v1 | Justificativa / referência |
|---|:-:|:-:|---|
| A.5.1 Policies | ✅ | ✅ | ISMS existente aplicável ao Basa sem alteração |
| A.5.2 Roles | ✅ | ✅ | RACI Fase 00 `scope.md` |
| A.5.3 Segregation | ✅ | ✅ | 2 reviewers prod (Fase 06) |
| A.5.4 Mgmt commitment | ✅ | ✅ | Management Review cobre Basa |
| A.5.5 Contact with authorities | ✅ | ✅ | inalterado |
| A.5.6 Special interest groups | ✅ | ✅ | Red Hat security mailing list adicionada |
| A.5.7 Threat intel | ✅ | ✅ | Red Hat OVAL + KrakenD feed |
| A.5.8 Infosec in project mgmt | ✅ | ✅ | Esta Fase 00..08 |
| A.5.9 Inventory of assets | ✅ | 🛠 | Tags OCI obrigatórias (Fase 02); export mensal |
| A.5.10 Acceptable use | ✅ | ✅ | inalterado |
| A.5.11 Return of assets | ✅ | ✅ | offboarding inclui OCI/OCP revocation |
| A.5.12 Classification | ✅ | ✅ | defined tag `data-classification` |
| A.5.13 Labelling | ✅ | ✅ | labels K8s + tags OCI |
| A.5.14 Transfer | ✅ | ✅ | TLS edge + service-ca (Fase 03) |
| A.5.15 Access control | ✅ | ✅ | OCI IAM + OCP RBAC |
| A.5.16 Identity mgmt | ✅ | ✅ | Identity Domain (Fase 06) |
| A.5.17 Auth info | ✅ | ✅ | ESO + Vault (Fase 05) |
| A.5.18 Access rights | ✅ | ✅ | Policies per compartment |
| A.5.19 Supplier relationships | ✅ | ✅ | OCI + RH contracts |
| A.5.20 Supplier agreements | ✅ | ✅ | DPA + MSA arquivados |
| A.5.21 Supply chain | ✅ | ✅ | Cosign + SBOM + SLSA (Fase 05) |
| A.5.22 Supplier monitoring | ✅ | ✅ | OCI Health + RH Insights |
| A.5.23 Cloud services | ✅ | ✅ | ADR-001..004 (Fase 00) |
| A.5.24 Incident planning | ✅ | ✅ | IRP + delta Fase 08 |
| A.5.25 Event assessment | ✅ | ✅ | Alertmanager + OCI Monitoring |
| A.5.26 Incident response | ✅ | ✅ | Rollback (Fase 06) + IRP |
| A.5.27 Learning | ✅ | ✅ | RCA obrigatório 48h |
| A.5.28 Evidence collection | ✅ | ✅ | compliance-oci.yml 7 anos retention |
| A.5.29 Infosec disruption | ✅ | ✅ | HA (Fase 02/03) + BCP |
| A.5.30 ICT readiness BC | ✅ | 🛠 | DR runbook cross-region (Fase 08) |
| A.5.31 Legal compliance | ✅ | ✅ | Rekor + Vault audit |
| A.5.32 IP | ✅ | ✅ | LICENSE |
| A.5.33 Protection of records | ✅ | ✅ | Object Storage archive 7 anos |
| A.5.34 Privacy | ✅ | ✅ | sem PII em labels |
| A.5.35 Independent review | ✅ | ✅ | compliance daily |
| A.5.36 Compliance checks | ✅ | ✅ | Trivy + audit.sh |
| A.5.37 Documented procedures | ✅ | 🛠 | Runbooks Fase 08 |

### A.6 — People

| Controle | Aplica? | Status | Justificativa |
|---|:-:|:-:|---|
| A.6.1 Screening | ✅ | ✅ | HR process |
| A.6.2 Terms | ✅ | ✅ | idem |
| A.6.3 Training | ✅ | 🛠 | OCI + OCP training no onboarding |
| A.6.4 Disciplinary | ✅ | ✅ | HR |
| A.6.5 Post-employment | ✅ | ✅ | IAM revocation |
| A.6.6 NDA | ✅ | ✅ | HR |
| A.6.7 Remote working | ✅ | ✅ | Bastion + MFA |
| A.6.8 Event reporting | ✅ | ✅ | Slack + Audit |

### A.7 — Physical

| Controle | Aplica? | Status | Justificativa |
|---|:-:|:-:|---|
| A.7.1 Physical perimeter | ✅ | ✅ | delegado OCI (cert anexo) |
| A.7.2 Entry | ✅ | ✅ | delegado OCI |
| A.7.3 Offices/rooms | ✅ | ✅ | HR/OCI |
| A.7.4 Physical monitoring | ✅ | ✅ | delegado OCI |
| A.7.5 Threats | ✅ | ✅ | delegado OCI |
| A.7.6 Working in secure areas | ✅ | ✅ | delegado OCI |
| A.7.7 Clear desk/screen | ✅ | ✅ | HR policy |
| A.7.8 Siting of equipment | ✅ | ✅ | WFH guidelines |
| A.7.9 Off-premises | ➖ | — | **Não-aplicável** — laptops não armazenam key material prod (tudo em Vault). Justificativa da exclusão formal abaixo. |
| A.7.10 Storage media | ✅ | ✅ | OCI gerencia; Vault delete |
| A.7.11 Supporting utilities | ✅ | ✅ | delegado OCI |
| A.7.12 Cabling | ✅ | ✅ | delegado OCI |
| A.7.13 Maintenance | ✅ | ✅ | delegado OCI |
| A.7.14 Disposal | ✅ | ✅ | OCI + Vault delete policy |

### A.8 — Technological

| Controle | Aplica? | Status | Justificativa |
|---|:-:|:-:|---|
| A.8.1 User endpoints | ✅ | ✅ | Bastion + VPN |
| A.8.2 Privileged access | ✅ | ✅ | OCI DG + OCP RBAC + SCC |
| A.8.3 Info access restriction | ✅ | ✅ | NetPol + EgressFirewall |
| A.8.4 Source code | ✅ | ✅ | GitHub branch protection |
| A.8.5 Secure auth | ✅ | ✅ | RS256 + OIDC |
| A.8.6 Capacity | ✅ | ✅ | HPA + MAO |
| A.8.7 Anti-malware | ✅ | 🛠 | Trivy v1 + ACS v2 |
| A.8.8 Vuln mgmt | ✅ | ✅ | Trivy + OVAL |
| A.8.9 Config mgmt | ✅ | ✅ | Helm + TF |
| A.8.10 Info deletion | ✅ | ✅ | Vault + lifecycle |
| A.8.11 Data masking | ✅ | ✅ | Lua DLP |
| A.8.12 DLP | ✅ | ✅ | Vector filters |
| A.8.13 Backup | ✅ | 🛠 | etcd OCP backup runbook Fase 08 |
| A.8.14 Redundancy | ✅ | ✅ | 3 masters + multi-AD |
| A.8.15 Logging | ✅ | ✅ | Loki + OCI Audit |
| A.8.16 Monitoring | ✅ | ✅ | Prom/OTel/OCI |
| A.8.17 Clock sync | ✅ | ✅ | RHCOS NTP |
| A.8.18 Privileged utilities | ✅ | ✅ | Bastion TTL 1h prod |
| A.8.19 Installation | ✅ | 📝 | policy-controller documentado (opcional v1) |
| A.8.20 Networks | ✅ | ✅ | VCN + NSG |
| A.8.21 Network services | ✅ | ✅ | LB managed |
| A.8.22 Segregation | ✅ | ✅ | compartments + namespaces |
| A.8.23 Web filtering | ✅ | ✅ | HSTS + EgressFW |
| A.8.24 Cryptography | ✅ | ✅ | Vault HSM + FIPS-ready |
| A.8.25 SDLC | ✅ | ✅ | CI + sign |
| A.8.26 App security | ✅ | ✅ | JWT RBAC |
| A.8.27 Secure architecture | ✅ | ✅ | defense-in-depth |
| A.8.28 Secure coding | ✅ | ✅ | Trivy secret scan |
| A.8.29 Security testing | ✅ | ✅ | compliance-oci.yml |
| A.8.30 Outsourced dev | ✅ | ✅ | KrakenD CE + UBI |
| A.8.31 Env separation | ✅ | ✅ | compartments |
| A.8.32 Change mgmt | ✅ | ✅ | 2 reviewers prod |
| A.8.33 Test info | ✅ | ✅ | staging sintético |
| A.8.34 Audit protection | ✅ | 📝 | Compliance Operator (documentado) |

## Exclusão formal de A.7.9

**Controle A.7.9** — Security of off-premises assets.

**Declaração de não-aplicabilidade:**
Equipamentos off-premises (laptops de desenvolvedores) **não armazenam
material criptográfico de produção** do track Basa. Todo segredo é
gerenciado via **OCI Vault** (HSM em staging+prod) e entregue a pods via
**External Secrets Operator**. Desenvolvedores acessam infra de produção
apenas via **OCI Bastion** com TTL curto (1h) e MFA — nenhum token
persistente.

Portanto, o risco coberto por A.7.9 não se materializa. O controle é
formalmente excluído da SoA do track Basa.

**Revisão:** anual.

## Implementação prevista (status 🛠 e 📝)

| Controle | Fase Plano | Status alvo |
|---|---|---|
| A.5.9 Asset inventory | Fase 02 | 🛠 → ✅ ao final de Fase 02 exec |
| A.5.30 BC readiness | Fase 08 | 🛠 → ✅ pós runbook DR |
| A.5.37 Docs procedures | Fase 08 | 🛠 → ✅ pós runbooks |
| A.6.3 Training | Pós v1 | 🛠 → ✅ quando onboarding OCI ativo |
| A.8.7 Anti-malware | Fase 05 | 🛠 → ✅ (Trivy) / 📝 → ✅ v2 (ACS) |
| A.8.13 Backup | Fase 08 | 🛠 → ✅ pós runbook |
| A.8.19 Installation | Fase 05 | 📝 → ✅ se policy-controller adotado |
| A.8.34 Audit protection | Fase 03/07 | 📝 → ✅ com Compliance Operator |

## Governance

- SoA revisada **anualmente** na Management Review (Cl. 9.3).
- Qualquer mudança de aplicabilidade requer **ADR novo** em
  `00-foundation/`.
- `compliance-oci.yml` valida coerência SoA ↔ controls-matrix (Fase 06).

## Checklist pronto-para-código

- [ ] SoA aprovada por ISO Lead + Platform Owner.
- [ ] Exclusão A.7.9 formal arquivada.
- [ ] Itens 🛠 têm dono + prazo.
- [ ] compliance-oci.yml check `soa-vs-matrix` passa.
- [ ] Management Review 2026 inclui review.
