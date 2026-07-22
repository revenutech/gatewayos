# Contrato de Tópicos de Evento — Revenu Platform

**Arquiteto Principal:** Gustavo Armoa

> Nomes de tópico Kafka são **contrato publicado entre módulos**. Este
> documento registra a convenção e o procedimento de mudança. Ele existe
> porque esse conhecimento vivia apenas como comentário solto dentro de
> `identityos-revenu/internal/worker/outbox_processor.go`.

---

## 1. Convenção

```
{módulo}.{bounded-context}
{módulo}.{bounded-context}.dlq
```

O prefixo é o **nome canônico do módulo**, igual ao usado no path público do
gateway e no Service Kubernetes. Não se usa apelido, abreviação nem o nome
histórico do repositório.

| Módulo | Prefixo | Exemplos |
|---|---|---|
| IdentityOS | `identityos.` | `identityos.identity`, `.session`, `.consent`, `.security`, `.audit` |
| OnboardOS | `onboardos.` | `onboardos.onboarding`, `.kyc`, `.screening` |
| AccountOS | `accountos.` | `accountos.account`, `.product`, `.fee`, `.statement` |
| LedgerOS | `ledger.` | `ledger.postings.confirmed`, `.balances.updated` |
| PaymentOS | `paymentos.` / `pix.` / `ted.` | por trilho |
| AuthorityOS | por domínio regulatório | `blkg-order-*`, `cadocs-document-*` |

---

## 2. Onde o contrato é materializado

Renomear um tópico exige tocar **todos** estes pontos, na mesma janela:

| Papel | Onde |
|---|---|
| **Provisionamento** | `ledgeros/docker/init-scripts/kafka/create-topics.sh` — cria tópicos e DLQs |
| **Produtor** | o outbox do módulo dono (ex.: `identityos-revenu/internal/worker/outbox_processor.go`) |
| **Consumidores** | `wss-gateway-revenu/src/internal/consumer/manager.go` e o `kafka_subscriber.go` de cada módulo |
| **Testes de contrato** | asserts que travam o nome (ex.: `event_mapper_test.go`, `kafka_subscriber_test.go`) |

Um rename parcial **não gera erro**: o consumidor assina um tópico que existe
mas nunca recebe mensagem. A falha é silenciosa — eventos somem.

---

## 3. Procedimento de renomeação

1. Levantar todos os consumidores (`grep` pelo nome exato do tópico em todos
   os repositórios, não só no módulo dono).
2. Provisionar o tópico novo em `create-topics.sh`, mantendo o antigo.
3. Publicar nos dois durante a janela de migração.
4. Migrar consumidor a consumidor.
5. Remover o tópico antigo quando a métrica de consumo zerar.

Alternativa aceitável quando todos os repositórios estão sob controle e podem
ser alterados juntos: rename atômico em uma única passada, com build e testes
de contrato verdes em cada repositório antes do merge.

---

## 4. Histórico

**2026-07-22 — `ident` + `os` (nome antigo, sem o "ity") → `identityos`**

> Nota: os nomes antigos aparecem abaixo com um marcador de escape (`ident\u200bos`)
> para sobreviverem a varreduras futuras de renomeação. Sem isso, um
> `sed` global torna o registro histórico ininteligível — foi o que aconteceu
> na primeira versão deste documento.

O IdentityOS publicava em `ident​os.*` enquanto o módulo, o chart Helm, o
Service Kubernetes e o path do gateway já eram `identityos`. A plataforma
carregava os dois nomes em camadas diferentes ao mesmo tempo.

Renomeado em **539 arquivos, 15 repositórios**, cobrindo tópicos Kafka,
pacotes protobuf, diretórios de pacote Go, client OAuth, helpers Helm, SPI
Java, rotas do BFF e documentação.

Na mesma passada foi corrigida uma divergência mais séria: os **pacotes
protobuf dos clientes estavam fora de sincronia com o servidor**.

```
servidor (identityos):   /identityos.v1.IdentityService/RegisterIdentity
clientes (onboardos,
          financeos):    /ident​os.v1.IdentityService/RegisterIdentity
```

Toda chamada gRPC entre eles falharia com `Unimplemented`. Não havia sintoma
porque os gateways estavam em modo `stub` — o defeito estava latente desde
que as cópias do contrato foram feitas.

---

## 5. Regra

Ao renomear um módulo, o nome muda **junto** em: path do gateway, backend do
gateway, Service e labels Kubernetes, chart Helm, prefixo de tópico Kafka,
pacote protobuf, diretório do pacote Go e client OAuth. Renomear só uma
dimensão é como a plataforma acumulou `identityos` × `identityos` em camadas
diferentes ao mesmo tempo.
