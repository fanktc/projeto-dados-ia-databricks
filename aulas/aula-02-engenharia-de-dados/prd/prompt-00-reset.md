# Setup 00 · Apagar tudo

**Não é um dos seis.** É o que você roda *antes* deles, para provar que os seis
bastam.

> Um projeto que você não consegue apagar é um projeto que você não consegue
> reconstruir — você só tem sorte de ele ainda estar de pé. Este script existe
> para que a resposta a *"e se eu perder tudo?"* seja **nove minutos**.

```bash
bash prd/00-reset.sh projeto-dados-ia             # simula, não apaga nada
bash prd/00-reset.sh projeto-dados-ia --apagar    # apaga de verdade
```

## O que ele apaga

| # | O quê | Como |
|---|---|---|
| 1 | Jobs, dashboards e Genie space no workspace | `databricks bundle destroy --target dev` |
| 2 | O catálogo `lakehouse_rotaperfume` inteiro — bronze, silver, gold e o volume | `DROP CATALOG ... CASCADE` |
| 3 | A pasta local `rotaperfume/`, com todo o código dos seis prompts | `rm -rf` |

Depois disso o workspace fica **sem o catálogo da noite 1**. É proposital: os
seis prompts recriam o catálogo, os três schemas, o volume, as dez tabelas
bronze, a silver, a gold, os testes, o dashboard e o Genie — do nada.

## Por que ele pede `--apagar`

Sem a flag, ele só imprime o que faria. `DROP CATALOG CASCADE` não tem desfazer,
e a pior hora para descobrir isso é ao vivo.

A flag se chama **`--apagar`**, e não `--sim`, de propósito: `--sim` fica ao
lado da palavra "simula" e alguém acaba lendo como *simulate* — rodando o modo
destrutivo achando que era o seguro.

## Como usar na preparação da aula

```bash
bash prd/00-reset.sh projeto-dados-ia --apagar  # zera
# ... roda prompt-01 a prompt-06 ...
git checkout -b gabarito && git add . && git commit -m "gabarito da noite 2"
```

Rode os seis pelo menos uma vez antes da aula e guarde o resultado na branch
`gabarito`. Você provavelmente não vai precisar. Mas se um prompt travar ao
vivo, `git checkout gabarito -- aulas/aula-02-engenharia-de-dados/rotaperfume/`
resolve em cinco segundos, e a aula continua.
