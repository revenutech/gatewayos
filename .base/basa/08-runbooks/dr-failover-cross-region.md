# Runbook — DR Failover Cross-Region

**Arquiteto Principal:** Gustavo Armoa

## Objetivo

Recuperar o Gateway em região OCI alternativa quando a região primária
(`sa-saopaulo-1`) estiver indisponível > RTO (4h). Aplica apenas ao
**track Basa pro**.

## Owner / Backup

- **Owner:** Platform Owner.
- **Backup:** SRE Lead.
- **Aprovador:** Platform Owner + ISO Lead.
- **RTO:** 4h.
- **RPO:** 15 min (Gateway é stateless — apenas config + bloom filter).

## Trigger

- OCI status indica outage de `sa-saopaulo-1` confirmado > 1h **e**
  estimativa de recovery > 3h.
- Incidente causando perda de compute em `sa-saopaulo-1` sem
  auto-recovery visível.
- Drill anual planejado.

## Pre-requisitos (estado steady / "cold-standby")

Para DR ser viável, manter em estado pronto:

- [ ] **Região alvo:** `sa-vinhedo-1` (Vinhedo/SP).
- [ ] **Terraform state** em bucket replicado (OCI Cross-Region Object
      Storage replication habilitado).
- [ ] **tfstate** acessível via qualquer região.
- [ ] **OCIR** com replication para região secundária (ativar replication
      policy no OCIR pro — decisão em Fase 02 ADR).
- [ ] **Vault** criado também em `sa-vinhedo-1` com keys correspondentes
      (KMS keys são region-bound; re-criar).
- [ ] **DNS** — zona `oci.allenty.io` pode apontar para IP do LB
      alternativo (TTL 60s já configurado — Fase 02).
- [ ] **Código/config:** repo git é single source, acessível de qualquer região.
- [ ] **OCP install-config** versionado para `sa-vinhedo-1` em
      `deployment/infra/oci/environments/pro-dr/`.
- [ ] **Compute capacity reservation** em `sa-vinhedo-1` (compra mensal
      pequena — ~$100/mês — garante shape disponível).

## Procedimento

### 1. Confirmar outage

```
oci health service list --region sa-saopaulo-1
# verificar status OCE+LB+Compute
```

Consultar OCI Status Dashboard `status.oraclecloud.com`.

Se confirmed, abrir **incidente P0**, notificar stakeholders.

### 2. Acionar DR

Comando mestre (single operator, coordenado):

```
cd deployment/infra/oci/environments/pro-dr

terraform init \
  -backend-config="bucket=revenu-platform-tf-state-oci" \
  -backend-config="key=gateway-basa/pro-dr/terraform.tfstate" \
  -backend-config="region=sa-vinhedo-1"

terraform apply -target=module.vault      # primeiro
# Se vault em outra região ainda não existe, criar + replicar secrets
```

### 3. Restaurar secrets no Vault da região DR

Script `tools/dr/restore-secrets-to-region.sh`:

```
# Pull de secrets da região primária (se ainda acessível)
oci vault secret list --compartment-id $COMPARTMENT --region sa-saopaulo-1 \
  --output json > /tmp/secrets.json

# Push para Vault da região DR
for s in $(jq -r '.data[] | @base64' /tmp/secrets.json); do
  # ... migrate each secret with proper KMS key reference
done
```

Alternativa (steady-state): secrets replicados via cronjob (manter
cópia atualizada em Vault da região DR).

### 4. Apply restante

```
terraform apply -target=module.vcn -target=module.dns
# delegação NS já aponta para ns.oraclecloud.com globalmente — vai resolver

terraform apply -target=module.openshift    # ~45 min
```

### 5. Restaurar kubeconfig

```
export KUBECONFIG=$(terraform output -raw kubeconfig_path)
oc whoami
oc get nodes
```

### 6. Aplicar manifests bootstrap

Mesmo que [bootstrap-first-apply.md](bootstrap-first-apply.md) passo 7
(operators + ESO + cert-manager + logging etc).

Script idealmente automatizado:
```
bash tools/dr/apply-bootstrap-manifests.sh
```

### 7. Deploy do Gateway (via CD)

```
# Override para região DR:
gh workflow run cd-pro-oci.yml \
  --ref v1.4.0 \
  -f image_tag=v1.4.0 \
  -f change_ticket=DR-FAILOVER-${DATE}
```

Secrets `OCP_KUBECONFIG_SECRET_OCID_PRO` já foi atualizado para Vault
da região DR no passo 3.

### 8. Redirecionar DNS

Ponto crítico — DNS aponta para novo LB:

```
NEW_LB_IP=$(terraform output -raw ingress_lb_ip)

oci dns record rrset update \
  --zone-name-or-id oci.allenty.io \
  --domain gateway.oci.allenty.io \
  --rtype A \
  --items "[{\"domain\":\"gateway.oci.allenty.io\",\"rtype\":\"A\",\"ttl\":60,\"rdata\":\"${NEW_LB_IP}\"}]"
```

TTL 60s → propagação em ~2 min.

### 9. Smoke

```
for i in $(seq 1 30); do
  curl -fsS --max-time 5 https://gateway.oci.allenty.io/__health
  sleep 2
done
```

Pelo menos 25/30 devem retornar 200.

### 10. Notificar

- Slack `#revenu-incidents`: "Gateway OCI DR failover to sa-vinhedo-1 COMPLETE. ETA restore to sa-saopaulo-1: TBD."
- Email stakeholders.
- OCI Support: manter aberto o ticket da região primária.

## Pós-failover — fallback para primária

Quando `sa-saopaulo-1` voltar:

1. **Não reverter imediatamente** — deixar DR rodar por ≥24h para
   estabilizar.
2. **Sync secrets/state** de volta.
3. **Redirect DNS** gradualmente (dois records → weighted 10/90 → 50/50
   → 100/0).
4. **Validate** cada etapa.
5. **Terminate DR cluster** depois de 7 dias de operação estável em
   primária.

Documentado em runbook separado `dr-recovery-to-primary.md`
(não escopo desta fase — criar se precisar).

## Evidência a gerar

- Timeline completo em `/compliance/evidences/runbooks/{yyyy-mm-dd}-dr-failover.md`.
- Outputs `terraform apply` de cada etapa.
- Screenshot OCI Status Dashboard confirmando outage primária.
- DNS change history.
- Smoke test output (pré + pós).
- RCA assinado em 7 dias.

## Escalação

- DR failover não completa em 4h (RTO breach) → Platform Owner +
  C-level notification.
- OCI Support não responde → Red Hat Support ou parceiro.
- Vault DR não tem secrets (gap de replicação) → emergency
  regeneration de JWKS + Redis password via bastion + manual distribution.

## Drill

**Semestral (tabletop):** simular outage, correr mentalmente através do
procedimento, atualizar runbook.

**Anual (real):** rodar failover completo em ambiente **uat-dr**
(criar equivalente uat em `sa-vinhedo-1`). Medir RTO real. Registrar
em `/compliance/evidences/runbooks/drills/{yyyy}-dr-drill.md`.

## Relacionado

- Fase 00 — risco B-R01 (lock-in região).
- Fase 02 — modules + environments.
- Fase 07 — BCP evidence.
- [rollback.md](rollback.md).

## Changelog

- 2026-04-17 — v1 inicial. Baseline cold-standby, RTO 4h.

## Notas de aprimoramento futuro

- **Warm standby** — cluster OCP idle em `sa-vinhedo-1` com 1 master +
  1 worker (custo +$200/mês, RTO <30min).
- **Active/Active** — requer redesign de bloom filter state, Redis
  cross-region replication, JWKS consistency. Fora do escopo v1.

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
