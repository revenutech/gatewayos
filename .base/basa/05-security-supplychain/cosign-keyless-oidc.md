# Cosign Keyless via GitHub OIDC

## Objetivo

Assinar imagens do Gateway em OCIR sem guardar chave privada, usando
**Cosign keyless** — certificado efêmero emitido pelo **Fulcio** mediante
OIDC token do GitHub Actions, registro em **Rekor** para transparência.
Equivalente ao fluxo já usado no track GCP.

## Equivalência

| GCP (atual) | Basa |
|---|---|
| `sigstore/cosign-installer@v3` no workflow | Idem |
| `cosign sign --yes` contra Artifact Registry | `cosign sign --yes` contra OCIR |
| GCP registry: Cosign grava `.sig` layer | OCIR idem (especificação OCI artifact) |
| `cosign verify` com `--certificate-identity` GH repo | Idem |

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
  --certificate-identity "https://github.com/revenutech/revenu-platform-gateway/.github/workflows/cd-production-oci.yml@refs/tags/v1.0.0" \
  --certificate-oidc-issuer "https://token.actions.githubusercontent.com" \
  ${OCIR_REPO}/gateway@${DIGEST}
```

Policy aceita **apenas**:
- Subject = workflow path + ref (prod = tag `v*.*.*`).
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

GitHub **environment protection** no `production-oci`:
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
