# 🗓️ As noites da imersão

Cada pasta é autocontida: README próprio, exemplos numerados em progressão e o
que for preciso para rodar.

| Noite | Tema | Entregável | Gravação |
|---|---|---|---|
| [**01**](aula-01-databricks-sql) · seg 24/08 | Databricks & SQL | Ambiente de pé, dado no catálogo, análise em 3 ambientes | [assistir](https://youtube.com/live/plG6mF-ib_w) |
| [**02**](aula-02-engenharia-de-dados) · ter 25/08 | Engenharia de dados | 6 prompts, 6 deploys: raw, bronze, silver, gold, dashboard e Genie | [assistir](https://www.youtube.com/watch?v=0KRcn4ZIDPg) |
| [**03**](aula-03-ciencia-de-dados) · qua 26/08 | Ciência de dados | 3 prompts, 3 deploys: features, modelo no UC e a fila dos 200 | [assistir](https://youtube.com/live/xAYkMee5OpA) |
| [**04**](aula-04-app-e-genie) · qui 27/08 | Apps e agentes | 3 prompts, 3 deploys: o Genie da direção, o app e o retorno da ligação | [assistir](https://youtube.com/live/EnBiOrp-0_Q) |

## O fio que liga as noites

```
  noite 1            noite 2             noite 3            noite 4
  ───────            ───────             ───────            ───────
  a query quebra  →  vira camada      →  vira decisão   →   vira produto
  no dado sujo       que roda sozinha    modelo e fila      app, Genie e o
                                         dos 200            retorno da ligação

  "qual foi         "como não           "com quem meu      "e quem não
   a receita?"       repetir isso?"      vendedor fala      escreve SQL?"
                                         amanhã?"
```

O mesmo `rotaperfume_pipeline` atravessa as noites 2, 3 e 4: começa com uma
tarefa e termina com **dezesseis**. ML não ganha repositório novo — entra como
mais uma camada, com os mesmos testes que quebram o job. O app da noite 4 é o
único artefato com ciclo de deploy próprio, porque tem build e compute
próprios — mas lê exatamente as mesmas tabelas.

Cada noite existe por causa do problema que a anterior deixou aberto. A noite 1
termina com uma query que falha por causa de datas em dois formatos — e é
exatamente isso que a noite 2 resolve.

**E a noite 4?** Ela era "deploy" no plano original, e essa versão saiu de
propósito: deploy não é etapa de fim de projeto, é o que acontece toda vez que
você termina alguma coisa — por isso ele acontece **seis vezes dentro da noite
2**. O que sobrou para a quinta-feira é a pergunta que as três primeiras noites
deixam aberta: **quem, fora do time de dados, consegue usar isso?** A resposta
é um app e um Genie — e o caminho de volta, com o retorno da ligação virando
dado.

## Como rodar qualquer exemplo

```bash
python3 scripts/run_sql.py aulas/aula-01-databricks-sql/exemplo-01-primeiro-select.sql
```

Alguns arquivos têm query que **falha de propósito** (é o momento de aula).
Nesses, use `--continuar`.
