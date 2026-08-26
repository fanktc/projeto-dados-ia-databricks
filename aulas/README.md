# 🗓️ As noites da imersão

Cada pasta é autocontida: README próprio, exemplos numerados em progressão e o
que for preciso para rodar.

| Noite | Tema | Entregável | Gravação |
|---|---|---|---|
| [**01**](aula-01-databricks-sql) · seg 24/08 | Databricks & SQL | Ambiente de pé, dado no catálogo, análise em 3 ambientes | [assistir](https://youtube.com/live/plG6mF-ib_w) |
| [**02**](aula-02-engenharia-de-dados) · ter 25/08 | Engenharia de dados | 6 prompts, 6 deploys: raw, bronze, silver, gold, dashboard e Genie | [assistir](https://www.youtube.com/watch?v=0KRcn4ZIDPg) |
| [**03**](aula-03-ciencia-de-dados) · qua 26/08 | Ciência de dados | 6 prompts, 6 deploys: features, modelo no UC, score, testes de modelo e a carteira do dia | _ao vivo_ |

## O fio que liga as noites

```
  noite 1              noite 2              noite 3
  ───────              ───────              ───────
  a query quebra   →   vira camada      →   vira decisão
  no dado sujo         que roda sozinha     modelo e carteira

  "qual foi           "como não            "com quem meu vendedor
   a receita?"         repetir isso?"       fala amanhã?"
```

O mesmo `rotaperfume_pipeline` atravessa as noites 2 e 3: começa com uma
tarefa, termina com **dezoito**. ML não ganha repositório novo — entra como
mais uma camada, com os mesmos testes que quebram o job.

Cada noite existe por causa do problema que a anterior deixou aberto. A noite 1
termina com uma query que falha por causa de datas em dois formatos — e é
exatamente isso que a noite 2 resolve.

**E a noite 4?** Ela era "deploy", e saiu de propósito. Deploy não é etapa de
fim de projeto: é o que acontece toda vez que você termina alguma coisa. Por
isso ele acontece **seis vezes dentro da noite 2**, uma por prompt.

## Como rodar qualquer exemplo

```bash
python3 scripts/run_sql.py aulas/aula-01-databricks-sql/exemplo-01-primeiro-select.sql
```

Alguns arquivos têm query que **falha de propósito** (é o momento de aula).
Nesses, use `--continuar`.
