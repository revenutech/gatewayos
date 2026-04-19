# SBOM — CycloneDX

**Arquiteto Principal:** Gustavo Armoa

## Objetivo

Gerar **Software Bill of Materials** no formato CycloneDX para cada
release, publicá-lo como artifact, assiná-lo com Cosign e anexar como
attestation à imagem.

## Por que CycloneDX (vs SPDX)

- Mais rico para container images (suporta `operating-system`,
  `application`, `file` components).
- Nativo no Trivy (`--format cyclonedx`).
- Anchore Grype consome direto.
- SBOM-NTIA-minimum requirements: ambos atendem.
- Preferência do ecossistema RH (ACS, Red Hat Trusted Artifact Signer).

## Geração

### Via Trivy

```
trivy image \
  --format cyclonedx \
  --output sbom.cdx.json \
  "${OCIR_REPO}/gateway:${TAG}"
```

Saída contém:
- Componentes OS (UBI9 RPMs).
- Componentes aplicação (Go modules do KrakenD).
- Hashes SHA256/SHA512 por componente.
- PURL (Package URL) para cada item.
- Metadata (build timestamp, tool version).

### Via Syft (alternativa)

```
syft "${OCIR_REPO}/gateway:${TAG}" -o cyclonedx-json > sbom.cdx.json
```

Syft às vezes descobre mais pacotes que Trivy; usar Syft para SBOM e
Trivy para scan. Custo: dois tools. V1 usa **só Trivy** por simplicidade.

## Assinatura e attestation

### 1. Assinar SBOM como blob

```
cosign sign-blob --yes \
  --output-signature sbom.cdx.json.sig \
  --output-certificate sbom.cdx.json.crt \
  sbom.cdx.json
```

Publica `sbom.cdx.json.sig` + `sbom.cdx.json.crt` como artifacts do
release GitHub.

### 2. Anexar attestation à imagem

```
cosign attest --yes \
  --predicate sbom.cdx.json \
  --type cyclonedx \
  "${OCIR_REPO}/gateway@${DIGEST}"
```

Grava no OCIR como layer `*.att` ao lado da imagem, com predicate
`https://cyclonedx.org/schema`.

### 3. Verificar attestation (em runtime / policy)

```
cosign verify-attestation \
  --type cyclonedx \
  --certificate-identity-regexp ".+" \
  --certificate-oidc-issuer "https://token.actions.githubusercontent.com" \
  "${OCIR_REPO}/gateway@${DIGEST}" \
  | jq '.payload | @base64d | fromjson'
```

Output: o SBOM encapsulado em in-toto statement + cert + Rekor entry.

## Admission gate (opcional)

`ClusterImagePolicy` exige attestation `cyclonedx`:

```yaml
spec:
  authorities:
    - keyless:
        identities:
          - issuer: https://token.actions.githubusercontent.com
            subjectRegExp: ".+"
      attestations:
        - name: require-sbom
          predicateType: https://cyclonedx.org/schema
          policy:
            type: cue
            data: |
              import "strings"
              metadata: component: name: strings.Contains("gateway")
```

## Publicação — artifacts do GitHub Release

```yaml
- uses: softprops/action-gh-release@v1
  with:
    files: |
      sbom.cdx.json
      sbom.cdx.json.sig
      sbom.cdx.json.crt
```

Acessível em `https://github.com/.../releases/download/v1.0.0/sbom.cdx.json`.

## SLSA provenance (extra)

Além do SBOM, gerar provenance SLSA Level 3 via
`slsa-github-generator` ou `actions/attest-build-provenance`:

```yaml
- uses: actions/attest-build-provenance@v1
  with:
    subject-name: ${OCIR_REPO}/gateway
    subject-digest: ${DIGEST}
    push-to-registry: true
```

Complementa o SBOM com dados do build (workflow, commit, inputs).

## Verificação downstream

Consumidor pode rodar:

```
cosign verify-attestation \
  --type cyclonedx \
  --certificate-identity-regexp ".*cd-pro-oci\\.yml.*" \
  --certificate-oidc-issuer "https://token.actions.githubusercontent.com" \
  gru.ocir.io/revenutech/gateway-basa-pro/gateway:v1.0.0
```

E `trivy sbom sbom.cdx.json --format table` para listar CVEs num SBOM
offline.

## Red Hat Trusted Artifact Signer (opcional)

Red Hat oferece operator que provê Fulcio/Rekor **self-hosted** no
cluster — alternativa ao Sigstore público. Não necessário v1; avaliar
se auditoria exigir logs privados.

## Decisões de design

1. **Só Trivy para SBOM** v1 — um tool, cobertura suficiente para UBI.
2. **CycloneDX JSON**, não SPDX.
3. **Sign + attest** sempre; verificar no deploy.
4. **SBOM publicado no GitHub Release** — acessível a parceiros.
5. **SLSA provenance** via `attest-build-provenance` — complementa, não
   substitui.

## Controles ISO 27001

- A.8.8 — Management of technical vulnerabilities (SBOM permite tracking).
- A.8.28 — Secure coding.
- A.8.30 — Outsourced development (transparência de deps terceiros).
- A.5.31 — Legal/regulatory compliance.

## Checklist pronto-para-código

- [ ] Trivy gera `sbom.cdx.json` em cada build.
- [ ] `cosign attest --type cyclonedx` anexa ao digest.
- [ ] SBOM publicado no GitHub Release com sig + cert.
- [ ] `cosign verify-attestation` é um step separado no CD (bloqueia deploy).
- [ ] SLSA provenance adicionado.
- [ ] Downstream consumer consegue validar SBOM offline.

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
