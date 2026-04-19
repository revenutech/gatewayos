# Cosign Keyless via GitHub OIDC

**Arquiteto Principal:** Gustavo Armoa

## Objetivo

Assinar imagens do Gateway em OCIR sem guardar chave privada, usando
**Cosign keyless** — certificado efêmero emitido pelo **Fulcio** mediante
OIDC token do GitHub Actions, registro em **Rekor** para transparência.

## Fluxo (pipeline GitHub Actions)

```
GitHub Actions workflow
        ▼  id_token: write
        ▼  Solicita OIDC token assinado pelo GitHub
        ▼  (claims: repo, ref, sha, actor, workflow)
Cosign invoca Fulcio com o OIDC token
        ▼
Fulcio valida token, emite cert x509 efêmero (10 min TTL)
cujo SAN.emailAddress contém o OIDC subject
        ▼
Cosign assina manifest da imagem usando a private key descartável
        ▼
Registra a assinatura em Rekor (transparency log, imutável)
        ▼
Publica `.sig` como layer OCI no OCIR ao lado do manifest
```

## Pré-requisitos

1. Workflow GitHub Actions com `permissions: id-token: write`.
2. Imagem já pushada no OCIR (hash conhecido).
3. `cosign` CLI instalado (via `sigstore/cosign-installer@v3`).

## Comando de assinatura (pseudo-step)

```
- uses: sigstore/cosign-installer@v3
  with:
    cosign-release: v2.4.0

- name: Sign image
  env:
    COSIGN_EXPERIMENTAL: "1"
  run: |
    IMAGE_REF="${OCIR_REPO}/gateway@${IMAGE_DIGEST}"
    cosign sign --yes "$IMAGE_REF"
```

**IMPORTANTE:** assinar **por digest** (`@sha256:...`), não por tag —
evita signing de imagem errada em caso de tag mutation.

## Comando de verificação

```
cosign verify \
  --certificate-identity "https://github.com/revenutech/revenu-platform-gateway/.github/workflows/cd-pro-oci.yml@refs/tags/v1.0.0" \
  --certificate-oidc-issuer "https://token.actions.githubusercontent.com" \
  ${OCIR_REPO}/gateway@${DIGEST}
```

Policy aceita **apenas**:
- Subject = workflow path + ref (pro = tag `v*.*.*`).
- Issuer = `https://token.actions.githubusercontent.com`.

## Admission policy (opcional v1, recomendado v2)

Usar **Sigstore policy-controller** para forçar verificação em admission.

### Instalação

```yaml
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: policy-controller
  namespace: cosign-system
spec:
  channel: stable
  name: policy-controller
  source: community-operators
```

(Ou via Helm chart oficial, se Operator não disponível no catalog OCP.)

### ClusterImagePolicy

```yaml
apiVersion: policy.sigstore.dev/v1beta1
kind: ClusterImagePolicy
metadata:
  name: gateway-require-signature
spec:
  images:
    - glob: "gru.ocir.io/revenutech/gateway-basa-*/gateway*"
  authorities:
    - keyless:
        url: https://fulcio.sigstore.dev
        identities:
          - issuer: https://token.actions.githubusercontent.com
            subjectRegExp: "^https://github.com/revenutech/revenu-platform-gateway/\\.github/workflows/.+"
      ctlog:
        url: https://rekor.sigstore.dev
```

Namespace `gateway-{env}` recebe label `policy.sigstore.dev/include: "true"`
para que admission avalie.

## OCIR particularidades

- OCIR aceita `.sig` artifacts (OCI artifact spec). Sem configuração extra.
- Requer permissão de push no mesmo repo (Cosign usa o mesmo Docker
  credential).
- Tags esquisitas: Cosign cria tag `sha256-{digest}.sig` — OCIR lista como
  imagem separada. Retention policy deve ignorar sufixo `.sig` (regex).

## Rekor privado (opcional)

Se auditoria exigir log não-público:
- Self-host Rekor em OCI (fora do escopo v1).
- Cosign aponta para `--rekor-url https://rekor.internal.revenu.com.br`.

V1 usa Rekor público (`rekor.sigstore.dev`).

## Proteção do workflow

GitHub **environment protection** no `pro-oci`:
- Exige aprovação humana.
- Restringe branches/tags permitidos a `refs/tags/v*.*.*`.

Isso amarra o OIDC subject a um contexto aprovado.

## Trust Root pinning

Cosign cache de root keys em Sigstore TUF. Em CI:
```
cosign initialize --mirror https://tuf-repo-cdn.sigstore.dev
```

(Opcional — Cosign faz auto em primeiro uso.)

## Decisões de design

1. **Keyless default** — zero key management.
2. **Assinar por digest** — evita ambiguidade.
3. **Sigstore policy-controller opcional v1** — v2 obrigatório (bloco de segurança forte).
4. **Rekor público v1** — economizar operação; privado se auditoria pedir.
5. **Trust root pinado** — evita man-in-the-middle no TUF.

## Controles ISO 27001

- A.8.9 — Configuration management (imagens imutáveis e assinadas).
- A.8.24 — Use of cryptography.
- A.8.25 — Secure development life cycle.
- A.8.30 — Outsourced development (cadeia de confiança até KrakenD CE / UBI).
- A.5.31 — Legal / regulatory compliance (transparência Rekor).

## Checklist pronto-para-código

- [ ] Workflow `cd-*-oci.yml` tem `permissions: id-token: write`.
- [ ] `sigstore/cosign-installer@v3` pinado.
- [ ] Sign step assina por digest, não por tag.
- [ ] `cosign verify` step no deploy bloqueia imagens não assinadas.
- [ ] ClusterImagePolicy documentada (ativada v2).
- [ ] Retention OCIR ignora `*.sig` artifacts.
- [ ] Trust root TUF inicializado em CI.

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
