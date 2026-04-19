# Runbook — TLS on OpenShift

**Arquiteto Principal:** Gustavo Armoa

## Objetivo

Operar o ciclo de vida TLS do Route do Gateway: emissão inicial,
renovação, troubleshooting e rotação manual. Cobre cert externo
(cert-manager + Let's Encrypt) e interno (service-ca).

## Owner / Backup

- **Owner:** SRE Lead.
- **Backup:** Security Lead.

## Trigger

- Route novo criado e precisa de cert.
- Cert vence < 7 dias e cert-manager não renovou.
- Let's Encrypt rate limit atingido em sqa.
- Renovação falhou (DNS01 challenge error).
- Rotação forçada por incidente de segurança.

## Pre-checks

- [ ] cert-manager Operator instalado no cluster
      (`oc get csv -n openshift-operators | grep cert-manager`).
- [ ] `ClusterIssuer letsencrypt-staging` e `letsencrypt-prod` existem.
- [ ] `cert-manager-webhook-oci` instalado e configurado (DNS01 provider).
- [ ] Domínio `{env}.oci.allenty.io` delegado corretamente.
- [ ] User / dynamic group com policy de gravar TXT `_acme-challenge.*`
      no compartment DNS.

## Procedimento

### A. Emitir cert inicial

```
oc apply -f k8s/helm/gateway/templates/certificate.yaml \
  --dry-run=client -o yaml | oc apply -n gateway-{env} -f -
# Ou via Helm upgrade (normal):
helm upgrade gateway k8s/helm/gateway -n gateway-{env} \
  -f k8s/helm/gateway/values-oci-{env}.yaml
```

Verificar:

```
oc get certificate -n gateway-{env}
# NAME           READY   SECRET          AGE
# gateway-cert   True    gateway-tls     2m

oc get secret gateway-tls -n gateway-{env} -o yaml \
  | grep tls.crt | awk '{print $2}' | base64 -d \
  | openssl x509 -noout -dates -subject
```

Esperado:
- `Ready: True` em < 2 min se cache LE warm, < 5 min se cold.
- Secret `gateway-tls` com tls.crt/tls.key.

### B. Troubleshooting — Certificate Ready=False

1. **Verificar events:**
   ```
   oc describe certificate gateway-cert -n gateway-{env}
   oc describe challenge -n gateway-{env}
   oc describe order -n gateway-{env}
   ```

2. **Cenário: "dns-01 challenge presented fails to propagate"**
   - Validar que DNS01 provider consegue gravar:
     ```
     oc logs -n cert-manager deploy/cert-manager -f | grep oci
     ```
   - Confirmar TXT record:
     ```
     dig TXT _acme-challenge.gateway.{env}.oci.allenty.io
     ```
   - Se não aparece: checar policies OCI do dynamic group do
     cert-manager + cert-manager-webhook-oci pod restart.

3. **Cenário: Let's Encrypt rate limit**
   - Trocar temporariamente para `letsencrypt-staging` issuer.
   - Aguardar 1 semana antes de voltar a pro.
   - Em sqa, **sempre** usar uat (Fase 03 `values-per-env.md`).

4. **Cenário: OpenShift Route não reflete cert novo**
   - Reconciliar Route:
     ```
     oc annotate route gateway --overwrite -n gateway-{env} \
       cert-manager.io/reconcile=$(date +%s)
     ```
   - Se `externalCertificate` alpha ligado: checar feature gate.
   - Fallback: copiar manualmente:
     ```
     CERT=$(oc get secret gateway-tls -n gateway-{env} -o jsonpath='{.data.tls\.crt}' | base64 -d)
     KEY=$(oc get secret gateway-tls -n gateway-{env} -o jsonpath='{.data.tls\.key}' | base64 -d)
     oc patch route gateway -n gateway-{env} --type=merge -p "{\"spec\":{\"tls\":{\"certificate\":\"$CERT\",\"key\":\"$KEY\",\"termination\":\"edge\"}}}"
     ```
     (temporário — voltar para fluxo automático assim que possível).

### C. Rotação forçada (security incident)

1. **Revogar o cert atual no LE:**
   ```
   cmctl renew gateway-cert -n gateway-{env}
   ```
2. Isso dispara novo DNS01 challenge + novo cert emitido + Secret
   atualizado automaticamente.
3. **Route** reconcilia em < 1 min (cert-manager renewer).
4. **Verificar** cert novo tem serial diferente:
   ```
   openssl x509 -in <old.crt> -noout -serial
   openssl x509 -in <new.crt> -noout -serial
   ```

### D. Certs internos (service-ca)

service-ca é **automático** — rotaciona cert anualmente, CA a cada
~26 meses. Não há operação manual rotineira.

**Forçar rotação** (emergência):

```
# Refresh serving cert no service
oc delete secret <service>-serving-cert -n <namespace>
oc annotate svc <service> -n <namespace> --overwrite \
  service.beta.openshift.io/serving-cert-secret-name-
oc annotate svc <service> -n <namespace> --overwrite \
  service.beta.openshift.io/serving-cert-secret-name=<service>-serving-cert
# aguardar service-ca operator regenerar
```

Referência: `01-foundation/adr-003-tls-certmanager-vs-service-ca.md`.

## Pós-check

- [ ] `oc get certificate -n gateway-{env}` → Ready=True + Renewal < 60d.
- [ ] `curl -v https://gateway.{env}.oci.allenty.io/__health 2>&1 | grep 'issuer'`
      mostra Let's Encrypt.
- [ ] `curl -v https://...` sem warnings de cert (pro com LE pro, sqa com LE uat — warning esperado).
- [ ] Browser test — sem badge de "Not secure".

## Evidência a gerar

- Output `openssl x509 -dates` antes e depois (rotação).
- Log cert-manager do challenge bem sucedido.
- Screenshot Grafana mostrando 0% de requests com TLS error no período.

## Escalação

- LE rate limit atingido em pro → Security Lead decide sobre fallback
  (service-ca interno, cert-manual).
- DNS01 nunca propaga → network admin + OCI Support.
- Incidente de segurança envolvendo cert → IRP (`incident-response-oci.md`).

## Drill

**Trimestral:** forçar `cmctl renew` em uat. Validar
autorenewal em 5 min. Registrar em
`/compliance/evidences/runbooks/drills/{yyyy-q}-tls-drill.md`.

## Relacionado

- Fase 03 — `route-vs-ingress.md`.
- Fase 00 — `adr-003-tls-certmanager-vs-service-ca.md`.
- Fase 05 — secrets flow.

## Changelog

- 2026-04-17 — v1 inicial.

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
