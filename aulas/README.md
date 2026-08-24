# 🗓️ As quatro noites

Cada pasta é autocontida: README próprio, exemplos numerados em progressão e o
que for preciso para rodar.

| Noite | Tema | Entregável | Gravação |
|---|---|---|---|
| [**01**](aula-01-databricks-sql) · seg 24/08 | Databricks & SQL | Ambiente de pé, dado no catálogo, primeira análise | [assistir](https://youtube.com/live/plG6mF-ib_w) |
| [**02**](aula-02-engenharia-de-dados) · ter 25/08 | Engenharia de dados | Silver, gold, pipeline e testes | — |
| [**03**](aula-03-ciencia-de-dados-e-agentes) · qua 26/08 | Ciência de dados e agentes | Score de propensão e agente comercial | — |
| [**04**](aula-04-deploy) · qui 27/08 | Deploy | Job no ar, agendado e monitorado | — |

## O fio que liga as quatro

```
  noite 1              noite 2              noite 3              noite 4
  ───────              ───────              ───────              ───────
  a query quebra   →   vira camada      →   vira decisão     →   vira rotina
  no dado sujo         silver e gold        score e agente       job agendado

  "qual foi           "como não            "quem eu             "como isso
   a receita?"         repetir isso?"       procuro amanhã?"     não cai?"
```

Cada noite existe por causa do problema que a anterior deixou aberto. A noite 1
termina com uma query que falha por causa de datas em dois formatos — e é
exatamente isso que a noite 2 resolve.

## Como rodar qualquer exemplo

```bash
python3 scripts/run_sql.py aulas/aula-01-databricks-sql/exemplo-01-primeiro-select.sql
```

Alguns arquivos têm query que **falha de propósito** (é o momento de aula).
Nesses, use `--continuar`.
