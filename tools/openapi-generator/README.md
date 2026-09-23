# openapi-generator

Gera a especificação OpenAPI do gateway a partir dos **templates de endpoint** do
KrakenD. A saída é artefato **derivado** — nunca editada à mão.

```bash
python3 -m venv .venv && .venv/bin/pip install -r requirements.txt
.venv/bin/python generate.py --endpoints-dir ../../krakend/templates --output ../../docs/api/openapi.yaml
.venv/bin/python generate.py --endpoints-dir ../../krakend/templates --output ../../docs/api/openapi.json --format json
```

**Saída atual:** 36 templates · 381 paths · **506 operações** · OpenAPI **3.1.0** ·
22 tags. Validada com `openapi-spec-validator`.

## O que consertar aqui já custou

O `strip_go_templates` removia toda diretiva `{{ ... }}` com uma regra só. Isso
funciona quando ela está **dentro de aspas** (`"jwk_url": "{{ .x }}"` → `"jwk_url": ""`),
e quebra quando ela é o **valor nu** (`"disable_jwk_security": {{ .x }}` → `"...":`
pendurado, JSON inválido). O comentário Go multilinha `{{/* ... */}}` tinha o problema
oposto: contém `}`, e o `[^}]*` da regra geral parava no primeiro.

O resultado era **10 dos 36 templates pulados** — justamente os maiores (os 7 de
`paymentos`, mais `ledger_v1` e `onboardos_v1`) — e o gerador dizia apenas
`Warning: Could not parse ..., skipping` e seguia com **exit 0**. Saía uma spec de
**57** operações em vez de 506, e nada indicava que faltavam 88%.

⚠️ **Gerador que pula entrada e termina com sucesso é pior que gerador que falha.**
Se um template novo deixar de parsear, prefira `--strict` a confiar no aviso.

## A tag vinha do segmento errado

`infer_tag` devolvia `parts[1]` — o **segundo** segmento do path. Em
`/ledgeros/v1/admin/{path}` isso é `v1`. O resultado era `V1` com **284** operações,
`Jdpi` com 185, e depois `__ready`, `Healthcheck`, `Cob` e `Cobv`: spec válida e quase
não navegável.

Agora a tag sai do **módulo** (primeiro segmento), com refino por subdomínio onde o
módulo é grande demais para servir de rótulo — `paymentos` sozinho responde por 311 dos
381 paths, e vira `Paymentos — JDPI`, `— TED`, `— BankLink`, `— Corebanx`, `— Temenos`,
`— OAuth`, `— Routing`.

Path que não começa por módulo conhecido cai em **`General` de propósito**: é sinal de
path fora da convenção, não rótulo a inventar. Hoje há **um** — `GET /v1/app/version`.

## A lista de tags é derivada

Ela era um literal de 10 entradas (`Ledger`, `Payments`, `Automation`, `Identity`…)
que o `infer_tag` **nunca produzia**. A spec declarava um vocabulário e usava outro, e
nenhuma das duas listas casava com a outra.

Agora `spec['tags']` sai das tags que as operações de fato usam, com descrição vinda de
`TAG_DESCRIPTIONS` — e o gerador **avisa** se aparecer tag sem descrição. Declaradas e
usadas são o mesmo conjunto, por construção.

## Pendências conhecidas

- `servers` aponta para `api.revenu.com.br` / `api-staging.revenu.com.br`, e a **D9 do
  ADR-006** decidiu um TLD só: `.revenu.tech`. Sai junto com o rollout daquela decisão.
- As operações trazem `description: "Required roles: ..."` — **266 ocorrências**. Este
  repositório é **público**; conferir antes de commitar.
