# Regra: Identificadores de mensagem não se substituem

> **Quick Reference:** um identificador `AAAA.NNN.NNN.NN` significa **uma**
> mensagem. Nem o da ISO 20022 nem o próprio da Revenu podem receber semântica
> diferente da registrada. Vale para os dois igualmente.
> **Fonte:** ADR-060 em `ledgeros/.base/plans/00-governance/decision-records/ADR-060-internal-message-repository.md` · catálogo em `ledgeros/.base/aasc/iso20022/`

## Princípio

O identificador **é** o contrato. `acmt.019.001.04` é AccountClosingRequest para
qualquer sistema do mundo que fale ISO 20022, e `blkg.008.001.01` é o início de
bloqueio judicial para qualquer sistema da Revenu.

Reaproveitar um identificador para outra coisa não é escolha de nome: é fazer o
contrato mentir.

## As duas metades da regra

### 1. Domínio ISO 20022 nativo — `AAAA.NNN.NNN.NN`

| Proibido | Por quê |
|---|---|
| Declarar `urn:iso:std:iso:20022:tech:xsd:X` para XML que não valida contra o XSD de `X` | Uma contraparte que resolva o namespace espera uma mensagem e recebe outra |
| Usar um identificador ISO com significado próprio | O identificador é global; o significado não é nosso para redefinir |
| Alocar identificador dentro de business area da ISO | `RN_MSG_008`. A ISO pode alocar o mesmo número amanhã |
| Trocar a versão sem trocar o identificador | `AAAA.NNN.NNN.NN` — o último par É a versão. Mudança incompatível vira `+1` |

**Obrigatório:** mensagem ISO entra como **classe A**, adotada por referência, com
o XSD oficial versionado e verificável. `msgrepo xsd` confere.

### 2. Domínio próprio da Revenu

**A mesma regra, sem exceção.** `blkg.008.001.01` não é menos contrato por ser
nosso — é contrato entre nossos módulos, e trocá-lo por baixo quebra consumidor
do mesmo jeito.

| Proibido | Por quê |
|---|---|
| Reaproveitar identificador `WITHDRAWN` | Um consumidor antigo interpretaria a mensagem nova com o schema velho |
| Mudar o significado de um identificador registrado | Registrar é publicar. Republicar outra coisa no mesmo endereço é o defeito |
| Criar uma segunda definição para um fato já registrado | `RN_MSG_004` — um fato, uma definição. O emissor vive no BAH, não no identificador |
| Usar o nome do evento como nome de tópico e vice-versa | São coisas diferentes: o tópico deriva da BASE do identificador, o subject do identificador completo |

**Renomear a ÁREA é permitido** enquanto a mensagem não estiver registrada —
depois, é `msgrepo realloc`, e só até o marco de imutabilidade.

## O que fazer quando não existe identificador certo

Não force. Nesta ordem:

1. **Existe mensagem ISO que cobre o fato?** → classe **A**, por referência.
2. **Existe mensagem ISO parecida, mas o conteúdo é nosso?** → classe **B** em
   área própria, com `relatedTo` apontando a ISO. O parente fica declarado, e o
   namespace é `urn:revenu:msg:xsd:`.
3. **Não existe nada parecido?** → classe **C**, área própria, sem `relatedTo`.

O erro que esta regra existe para impedir é pular direto para "uso o
identificador da ISO que mais parece".

## Dois incidentes reais que originaram a regra

**InvestOS (MS-058 §20).** Catorze de dezessete declarações emitiam elemento raiz
inexistente no schema declarado. `secl.010` dizia `ClrMmbrRpt` quando o oficial é
`SttlmOblgtnRpt`; `reda.014` dizia `SctiesRpt` quando aquele identificador é
`PartyCreationRequest` — mensagem de outro assunto. O XML declarava o namespace
da ISO e não validava contra ele.

O defeito era **latente**: nada importava o pacote, então nenhum XML saía. Viraria
incidente no dia em que alguém ligasse o builder a um adaptador.

**AuthorityOS (MS-058 §19).** Transferência de reservas modelada em três lugares,
duas delas com entidades Go distintas dentro do mesmo módulo, e sem UETR. A
pergunta "esta transferência já aconteceu?" tinha duas respostas possíveis.

## Como verificar

```bash
# O identificador existe e o XSD confere (classe A)
cd ledgeros/tools/msgrepo && go run . xsd --repo ../../.base/aasc/iso20022

# As invariantes do catálogo, incluindo RN_MSG_004 e RN_MSG_008
go run . validate --repo ../../.base/aasc/iso20022

# O código não emite evento fora do catálogo
go run . drift --module <módulo> --src <caminho> --repo ../../.base/aasc/iso20022
```

O `MustID` do `revenu-common` derruba o processo no init se o identificador não
estiver no catálogo. É deliberado: processo que sobe emitindo mensagem fora do
catálogo é pior que processo que não sobe.

## Anti-patterns

| Evitar | Preferir |
|---|---|
| `urn:iso:...:reda.014` para um relatório de títulos | `reda.012`, que **é** SecurityReport |
| Escolher o identificador pelo nome que soa parecido | Conferir o elemento raiz contra o XSD oficial |
| Inventar área de 4 letras dentro do espaço da ISO | Área própria declarada em `business-areas.yaml` |
| Constante de tópico com o texto do tipo de evento | Tópico derivado do identificador |
| Reusar número de mensagem retirada | Alocar o próximo; retirado não volta |
