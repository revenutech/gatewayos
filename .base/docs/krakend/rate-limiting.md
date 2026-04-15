# Rate Limiting Configuration

## Overview

O rate limiter do KrakenD controla a quantidade de requisições permitidas por endpoint, protegendo os backends contra sobrecarga e ataques de negação de serviço.

**ISO 27001:** A.12.1.3 (Capacity management)

## Configuracao Atual

```json
"qos/ratelimit/router": {
  "max_rate": 3000,        // 3000 req/min global (50 req/s)
  "client_max_rate": 600,  // 600 req/min por cliente (10 req/s)
  "strategy": "ip",        // Identificacao por IP
  "every": "1m"            // Janela de tempo
}
```

### Parametros

| Parametro | Valor | Descricao |
|-----------|-------|-----------|
| `max_rate` | 3000 | Limite global do endpoint por minuto |
| `client_max_rate` | 600 | Limite por cliente (IP) por minuto |
| `strategy` | `ip` | Estrategia de identificacao do cliente |
| `every` | `1m` | Periodo de tempo para contagem |

### Valores por Ambiente

| Ambiente | Global (req/min) | Por Cliente (req/min) |
|----------|------------------|----------------------|
| SQA | 3000 | 600 |
| UAT | 3000 | 600 |
| Producao | Ajustar conforme SLA | Ajustar conforme SLA |

## Decisao Arquitetural: Strategy IP vs Header

### Problema

Originalmente, o rate limiter estava configurado com:
```json
"strategy": "header",
"key": "X-Tenant-ID"
```

Isso causava **429 Too Many Requests na primeira requisicao**, mesmo com tokens disponiveis.

### Causa Raiz

A ordem de execucao dos plugins no KrakenD e:
1. **Rate Limiter** (`qos/ratelimit/router`) - verifica X-Tenant-ID
2. **JWT Validator** (`auth/validator`) - propaga claims para headers

O header `X-Tenant-ID` so e populado pelo `propagate_claims` do JWT validator:
```json
"propagate_claims": [
  ["tenant_id", "x-tenant-id"],
  ...
]
```

Como o rate limiter executa **antes** do JWT validator, o header `X-Tenant-ID` ainda nao existe. Requisicoes sem o header compartilham um bucket comum, causando esgotamento imediato.

### Solucao

Alterado para `strategy: "ip"`, que identifica clientes pelo endereco IP.

**Vantagens:**
- Funciona independente da ordem de execucao dos plugins
- Protege contra ataques de DoS por IP
- Nao requer headers especiais na requisicao

**Limitacoes:**
- Clientes atras de NAT compartilham o mesmo bucket
- Um tenant pode ter multiplos IPs (limite por IP, nao por tenant)

### Alternativas para Producao

Se rate limiting por tenant for necessario em producao:

1. **Exigir header na requisicao original**
   - Cliente envia `X-Tenant-ID` no request
   - Usar `strategy: "header"` com `key: "X-Tenant-ID"`

2. **Rate limiting no backend**
   - Implementar rate limiting no servico backend
   - Executa apos JWT validation, tenant disponivel

3. **Middleware customizado**
   - Lua script que extrai tenant do JWT antes do rate limiter
   - Mais complexo, requer manutencao adicional

## Arquivos de Configuracao

### Templates

- `krakend/templates/rate_limiter.tmpl` - Template principal
- `krakend/partials/rate_limiter.tmpl` - Partial reutilizavel
- `krakend/partials/security/rate-limit.json` - Configuracao de seguranca

### Settings por Ambiente

- `krakend/settings/sqa/rate_limit.json` - Valores padrao SQA
- `krakend/settings/sqa/balances_read.json` - Rate limit para leitura de saldos
- `krakend/settings/sqa/postings_write.json` - Rate limit para escrita de postings

### Exemplo de Settings

```json
// rate_limit.json (padrao)
{
  "global_max": 3000,
  "tenant_max": 600
}

// postings_write.json (escrita - mais restritivo)
{
  "rate_limit": {
    "global_max": 1800,
    "tenant_max": 300
  }
}

// balances_read.json (leitura - menos restritivo)
{
  "rate_limit": {
    "global_max": 3000,
    "tenant_max": 600
  }
}
```

## Monitoramento

### Metricas Prometheus

O KrakenD expoe metricas de rate limiting:
- `krakend_router_rate_limit_rate` - Taxa atual
- `krakend_router_rate_limit_capacity` - Capacidade do bucket

### Logs

Quando rate limit e excedido:
```
[GIN] 2026/04/15 | 429 | GET "/ledgeros/v1/balances/1"
Error #01: rate limit exceded
```

## Troubleshooting

### 429 na Primeira Requisicao

**Sintoma:** Todas as requisicoes retornam 429 imediatamente apos restart do pod.

**Causa provavel:**
- `strategy: "header"` com header inexistente
- Bucket compartilhado esgotado

**Solucao:** Verificar se a estrategia esta correta (`ip` ou `header` com header presente).

### Rate Limit Muito Restritivo

**Sintoma:** Usuarios legitimos recebem 429 frequentemente.

**Solucao:**
1. Aumentar `client_max_rate` nos arquivos de settings
2. Considerar aumentar `max_rate` global
3. Verificar se multiplos clientes compartilham IP (NAT)

## Referencias

- [KrakenD Rate Limiting Documentation](https://www.krakend.io/docs/endpoints/rate-limit/)
- [Token Bucket Algorithm](https://en.wikipedia.org/wiki/Token_bucket)
- ISO 27001:2022 - A.12.1.3 Capacity management
