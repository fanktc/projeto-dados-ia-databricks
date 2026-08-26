# Os 6 prompts da Noite 3

**Imersão Jornada de Dados · Ciência de dados · Quarta 26/08 · 19h30**

> **Revisado com o resultado das duas primeiras noites.** Nota 9,5 na primeira,
> **9,6 na segunda** — e a segunda foi mais densa. A leitura: **a sala aguenta
> mais profundidade, não menos.**
>
> A consequência para hoje: nada de "o que é machine learning". O bloco que
> merece tempo é o que separa modelo de brinquedo — vazamento, baseline, teste
> de modelo e promoção.

---

## A ideia central da noite

Seis prompts, **seis deploys** — a mesma cadência da terça. O
`rotaperfume_pipeline` sai de **12 tarefas e termina com 18**, e continua sendo
um `bundle run` só.

```
prompt 1   + ml_features
prompt 2   + ml_treino
prompt 3   + ml_score
prompt 4   + ml_testes
prompt 5   + ml_carteira_do_dia
prompt 6   + ml_promocao (entre treino e score)
```

**Não existe "projeto de ML" separado.** ML é mais uma camada do mesmo
pipeline, no mesmo bundle, com os mesmos testes que quebram o job. É a tese da
noite, e o DAG é quem prova.

> **Isto foi rodado inteiro contra o workspace, com seed 42.** Os seis deploys
> deram verde, os 19 testes passam, e as armadilhas que apareceram no caminho
> estão escritas dentro de cada prompt — inclusive três que só existem no Free
> Edition e que teriam quebrado a aula ao vivo.

---

## A frase que abre a noite

Antes de qualquer slide, faça a pergunta e deixe a sala responder:

> **"Para quem o vendedor deve ligar amanhã?"**

Vem sempre "para quem parou de comprar" ou "para quem compra mais". Anote as
duas. No prompt 2, você mede as duas na frente deles:

| A resposta | AUC medido |
|---|---|
| "ligue para quem comprou recentemente" | **0,4329** — pior que jogar moeda |
| "ligue para quem compra mais" | 0,6432 |
| jogar uma moeda | 0,5000 |
| **o modelo** | **0,8667** |

> A intuição comercial não está imprecisa. Está **invertida** — porque
> distribuição funciona por ciclo de reposição: quem acabou de receber a
> mercadoria é justamente quem não compra agora.

**É o melhor momento da noite e ele acontece no prompt 2.** Não entregue antes.

---

## Os seis

| # | Entrega | Arquivo | Deploy |
|---|---|---|---|
| 1 | **Features** — a mesma função, dois cortes no tempo | [`prompt-01-features.md`](prompt-01-features.md) | 1ª |
| 2 | **Treino** — MLflow, Unity Catalog e o baseline que choca | [`prompt-02-treino.md`](prompt-02-treino.md) | 2ª |
| 3 | **Score** — o modelo vira tabela Delta na gold | [`prompt-03-score.md`](prompt-03-score.md) | 3ª |
| 4 | **Testes de modelo** — 8 testes que quebram o job | [`prompt-04-testes-de-modelo.md`](prompt-04-testes-de-modelo.md) | 4ª |
| 5 | **A decisão** — a carteira do dia, com motivo em português | [`prompt-05-a-decisao.md`](prompt-05-a-decisao.md) | 5ª |
| 6 | **Retreino** — challenger, promoção e rollback | [`prompt-06-retreino.md`](prompt-06-retreino.md) | 6ª |

---

## Os números que têm que aparecer

Todos medidos na execução real, com `seed 42`:

| Onde | Número |
|---|---|
| `features_treino` | 2.815 clientes × 22 features · 39,89% de positivos |
| `features_cliente` | 2.816 clientes, corte 2026-08-31 |
| **Baseline "quem comprou recente"** | **AUC 0,4329 — pior que moeda** |
| Baseline "quem compra mais" | AUC 0,6432 |
| **Modelo** | **AUC 0,8667 · ganho de +0,2235** |
| Feature nº 1 | **`atraso_relativo`** — a que não veio de biblioteca |
| Holdout | 704 clientes que o modelo não viu |
| Calibragem | Fria 11,7% → Muito quente **81,1%** compraram |
| Score | 2.816 clientes · 671 muito quentes (23,8%) |
| Carteira do dia | 1.290 contatos · 36 vendedores |
| Clientes grandes e atrasados | **35** — a lista da segunda de manhã |
| Receita recuperável | R$ 76.684/mês em 112 clientes |
| Demonstração de vazamento | honesto 0,8838 → vazado **1,0000** |
| Pipeline | **18 tarefas · 19 testes que quebram** |

---

## As três armadilhas do Free Edition

Medidas contra o workspace. Estão dentro dos prompts, mas vale saber antes:

1. **`mlflow.pyfunc.spark_udf` não funciona no serverless.** Levanta
   `InvalidVersion: '18.x-aarch64-photon-scala2'`. É o caminho que toda
   documentação recomenda. A saída é `load_model` + pandas — e para 2.816
   clientes isso é a escolha certa de qualquer forma.

2. **XGBoost treina e registra, mas não carrega de volta.** Conflito com o
   scikit-learn 1.6.1 do serverless (`__sklearn_tags__`). Só se descobre uma
   tarefa depois. Use `HistGradientBoostingClassifier`, que é nativo e não
   precisa de dependência nenhuma.

3. **`mlflow.set_experiment` não cria a pasta pai.** O erro é
   `BAD_REQUEST: For input string: "None"`, que não menciona pasta nenhuma.
   `WorkspaceClient().workspace.mkdirs(...)` antes resolve.

E uma quarta, que não é do Free Edition e sim da gold: **`DECIMAL` não
serializa em JSON.** Toda soma de receita precisa de `.cast("double")`, senão o
registro do modelo quebra com `Object of type Decimal is not JSON serializable`.

---

## O que muda em relação ao PRD original

| Antes | Agora | Por quê |
|---|---|---|
| Notebooks soltos (`n3_features.py`) | Tarefas do mesmo pipeline | ML não é projeto à parte |
| Modelo salvo como tabela de score | Modelo **registrado no UC**, com alias | É o que o Databricks tem de melhor aqui |
| Sem baseline | Baseline medido **antes** do treino | Sem régua, "AUC 0,87" não quer dizer nada |
| Testes só de dado | **8 testes de modelo** que quebram o job | Modelo ruim não dá erro — funciona |
| Agente com ferramentas em Python | Views de negócio que o Genie já lê | O trabalho de metadado da noite 2 paga sozinho |
| Retreino não mencionado | Challenger, promoção e rollback | É o que separa quem já pôs modelo em produção |

---

## Como conduzir

| Regra | Por quê |
|---|---|
| Faça a pergunta da carteira **antes** de abrir qualquer código | O resto da noite é a resposta dela |
| Segure o baseline até o prompt 2 | É o momento que a sala não espera. Não estrague |
| Abra o DAG depois de cada deploy | Continua sendo a melhor tela da aula |
| No prompt 4, **quebre um teste de propósito** | Teste que ninguém viu falhar não convence ninguém |
| Mostre a calibragem antes da carteira | 11,7% → 81,1% é o que constrói confiança no modelo |
| Não corrija tudo ao vivo | Um segundo prompt curto ensina mais que um conserto |

**Orçamento:** ~9 minutos por prompt, dos quais 5 a 6 são de fala sua.

---

## Cronograma

| Tempo | Bloco |
|---|---|
| 00:00–00:08 | Abertura · "para quem o vendedor liga amanhã?" e o recap das duas noites |
| 00:08–00:16 | O que é feature, o que é rótulo e por que a data de corte é tudo |
| 00:16–00:26 | **Prompt 1 · Features** |
| 00:26–00:38 | **Prompt 2 · Treino** — o baseline. **Não corte este bloco** |
| 00:38–00:47 | **Prompt 3 · Score** |
| 00:47–01:00 | **Prompt 4 · Testes de modelo** — com a quebra proposital |
| 01:00–01:12 | **Prompt 5 · A decisão** — a carteira do dia |
| 01:12–01:22 | **Prompt 6 · Retreino, promoção e rollback** |
| 01:22–01:30 | Fechamento e o DAG completo das três noites |
| 01:30–01:50 | **Abertura de carrinho** — depois da entrega, nunca antes |

> **Regra inegociável do PRD:** o carrinho abre **depois** da entrega técnica.
> A prova é o argumento de venda.
