#!/usr/bin/env python3
"""
check-cobertura-identityos.py — o gateway declara toda rota que o sandbox chama?

🔴 POR QUE POR METODO+CAMINHO, e nao so por caminho.

O FLOW-I0004 comparou CAMINHOS e deu 69 de 71 cobertas. Duas coisas escaparam:

  1. `POST /v1/iam/policies/evaluate` tem dois segmentos apos `/v1/iam/`, entao
     casa por forma com `{resource}/{id}` — que declara GET, PATCH e DELETE.
     Nao ha bloco POST naquela profundidade. Pelo caminho estava coberta;
     pelo metodo, nao.
  2. Tres rotas de notificacao na mesma situacao.

E o efeito de uma rota faltando NAO e um 404 limpo: e o panico do gin
(`redirectFixedPath` -> `invalid node type`) com a conexao morrendo sem
resposta. O cliente ve `fetch failed` e vai investigar rede.

Uso:
    python3 tools/check-cobertura-identityos.py [--sandbox ../navigatoros-sandbox]

Saida: 0 se toda chamada do front casa com uma declaracao, 1 caso contrario.
Rotas deliberadamente nao declaradas (porque o BACKEND nao as serve — RI-244)
vivem em NAO_DECLARADAS abaixo, com o motivo.
"""
import argparse
import os
import re
import sys

TEMPLATE = 'krakend/templates/endpoint_identityos_v1.tmpl'
PREFIXO_GW = '/identityos/v1/iam/'
PREFIXO_FRONT = '/v1/iam/'

# Chamadas do front que o identityos NAO serve. Declara-las exporia caminho
# inalcancavel (RI-123). Conferido em modules/shared/routes/routes.go.
#
# Eram QUATRO ate 2026-09-06: o `POST .../notification-channels/{kind}/test`
# saiu daqui quando o identityos passou a servi-lo (TI8.4.5).
NAO_DECLARADAS = {
    ('PATCH', '/v1/iam/me/notification-channels/{p}'): 'backend 404',
    ('PATCH', '/v1/iam/me/notifications/{p}/read'): 'backend 404',
    ('PATCH', '/v1/iam/me/notifications/read-all'): 'backend 404',
}


def declaracoes(caminho_tpl):
    """Pares (metodo, endpoint) declarados no template do gateway."""
    texto = open(caminho_tpl, encoding='utf-8').read()
    return {
        (m.group(2), m.group(1))
        for m in re.finditer(
            r'"endpoint":\s*"([^"]+)",\s*\n\s*"method":\s*"([A-Z]+)"', texto
        )
    }


def chamadas(raiz_sandbox):
    """Pares (metodo, caminho) que o front pede ao identityos.

    Interpolacao vira `{p}`: o que se compara e a FORMA do caminho por
    segmento, que e o que o roteador do gateway ve.
    """
    achados = set()
    base = os.path.join(raiz_sandbox, 'src/app/api')
    padroes = [
        r"identityosClient\.(get|post|patch|put|delete)<?[^(]*\(\s*`([^`]+)`",
        r"identityosClient\.(get|post|patch|put|delete)<?[^(]*\(\s*'([^']+)'",
    ]
    for pasta, _, arquivos in os.walk(base):
        for arq in arquivos:
            if arq != 'route.ts':
                continue
            texto = open(os.path.join(pasta, arq), encoding='utf-8').read()
            for padrao in padroes:
                for m in re.finditer(padrao, texto):
                    caminho = re.sub(r'\$\{[^}]+\}', '{p}', m.group(2))
                    if caminho.startswith(PREFIXO_FRONT):
                        achados.add((m.group(1).upper(), caminho))
    return achados


def casa(metodo, caminho, decls):
    """A chamada casa com alguma declaracao, por metodo E por segmento?"""
    segs = caminho[len(PREFIXO_FRONT):].split('/')
    for dm, dep in decls:
        if dm != metodo or not dep.startswith(PREFIXO_GW):
            continue
        # `auth/{path}` e o unico curinga que engole um segmento livre.
        if dep == PREFIXO_GW + 'auth/{path}':
            if segs[0] == 'auth' and len(segs) == 2:
                return dep
            continue
        dsegs = dep[len(PREFIXO_GW):].split('/')
        if len(dsegs) != len(segs):
            continue
        if all(d.startswith('{') or d == s for d, s in zip(dsegs, segs)):
            return dep
    return None


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--sandbox', default='../navigatoros-sandbox')
    ap.add_argument('--template', default=TEMPLATE)
    args = ap.parse_args()

    if not os.path.isdir(os.path.join(args.sandbox, 'src/app/api')):
        print(f'⚠️  sandbox nao encontrado em {args.sandbox} — nada a conferir')
        return 0

    decls = declaracoes(args.template)
    pedidas = chamadas(args.sandbox)
    print(f'{len(decls)} pares metodo+caminho declarados no gateway')
    print(f'{len(pedidas)} pares metodo+caminho chamados pelo sandbox')

    faltando, ignoradas = [], []
    for metodo, caminho in sorted(pedidas):
        if casa(metodo, caminho, decls):
            continue
        if (metodo, caminho) in NAO_DECLARADAS:
            ignoradas.append((metodo, caminho, NAO_DECLARADAS[(metodo, caminho)]))
        else:
            faltando.append((metodo, caminho))

    if ignoradas:
        print('\nnao declaradas de proposito (o backend nao serve):')
        for metodo, caminho, motivo in ignoradas:
            print(f'  ·  {metodo:<6} {caminho}  ({motivo})')

    if faltando:
        print('\n🔴 chamadas do front SEM declaracao no gateway:')
        for metodo, caminho in faltando:
            print(f'  🔴 {metodo:<6} {caminho}')
        print(
            '\nUma delas nao vira 404: `POST` numa profundidade sem bloco `POST`\n'
            'faz o gin entrar em redirectFixedPath e derrubar a conexao. O\n'
            'cliente ve `fetch failed`, nao "rota nao declarada".'
        )
        return 1

    print(f'\n✅ {len(pedidas) - len(ignoradas)} de {len(pedidas)} cobertas; '
          f'{len(ignoradas)} fora de proposito')
    return 0


if __name__ == '__main__':
    sys.exit(main())
