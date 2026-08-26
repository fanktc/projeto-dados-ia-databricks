# 🔮 Dia 3: Ciência de dados | Imersão Jornada de Dados

Ontem o pipeline passou a rodar sozinho. Ele responde muito bem uma pergunta:
**o que aconteceu.** Receita por mês, margem por categoria, quem parou de
comprar.

Hoje ele passa a responder outra: **o que fazer amanhã de manhã.**

> **Promessa da noite:** o dado vira decisão.
> **Pergunta da noite:** *"Com quem meu vendedor fala amanhã?"*
> **Formato:** [6 prompts, 6 deploys](prd/6-prompts-noite-3.md). O mesmo bundle
> da terça — o job sai de 12 tarefas e chega a 18.

---

## 🧠 A ideia da noite: ML é camada, não projeto

A tentação, quando entra machine learning num projeto de dados, é abrir um
repositório novo, um notebook solto, um ambiente à parte. É assim que nasce o
modelo que ninguém consegue colocar em produção.

Aqui ML entra como **mais uma camada do mesmo pipeline**: mesmo bundle, mesmo
job, mesmos testes que quebram, mesma auditoria de metadado. O DAG cresce e
continua sendo um `bundle run`.

```
raw → bronze → silver ×4 → dimensões → fato → marts → testes
                                             ├→ métricas → auditoria
                                             └→ ml_features → ml_treino →
                                                ml_promocao → ml_score →
                                                ml_testes → ml_carteira_do_dia
```

---

## ⚡ O momento da noite

Antes de qualquer código, a pergunta vai para a sala:

> **"Para quem o vendedor deve ligar amanhã?"**

As duas respostas de sempre são *"para quem parou de comprar"* e *"para quem
compra mais"*. No prompt 2 as duas são medidas na frente de todo mundo:

| A resposta | AUC medido |
|---|---|
| "ligue para quem comprou recentemente" | **0,4329** |
| jogar uma moeda | 0,5000 |
| "ligue para quem compra mais" | 0,6432 |
| **o modelo** | **0,8667** |

**A intuição comercial não está imprecisa — está invertida.** Distribuição
funciona por ciclo de reposição: quem acabou de receber a mercadoria é
justamente quem não compra agora. Ninguém tinha medido.

---

## 📋 Os seis prompts

Cada um num arquivo próprio, com o prompt copiável, o que falar enquanto o
Claude Code trabalha, como validar ao vivo e uma tabela **"se der errado"**.

| # | Entrega | Arquivo |
|---|---|---|
| 1 | **Features** — a mesma função, dois cortes no tempo | [`prompt-01-features.md`](prd/prompt-01-features.md) |
| 2 | **Treino** — MLflow, Unity Catalog e o baseline que choca | [`prompt-02-treino.md`](prd/prompt-02-treino.md) |
| 3 | **Score** — o modelo vira tabela Delta na gold | [`prompt-03-score.md`](prd/prompt-03-score.md) |
| 4 | **Testes de modelo** — 8 testes que quebram o job | [`prompt-04-testes-de-modelo.md`](prd/prompt-04-testes-de-modelo.md) |
| 5 | **A decisão** — a carteira do dia, com motivo em português | [`prompt-05-a-decisao.md`](prd/prompt-05-a-decisao.md) |
| 6 | **Retreino** — challenger, promoção e rollback | [`prompt-06-retreino.md`](prd/prompt-06-retreino.md) |

O roteiro da noite, com cronograma e as falas: [`6-prompts-noite-3.md`](prd/6-prompts-noite-3.md).

---

## 🧪 Notebooks para conferir o resultado

Para abrir **depois** que o pipeline rodou. São de leitura — não alteram nada.

| Notebook | Para quê |
|---|---|
| [`01-o-que-o-modelo-vale.sql`](notebooks/01-o-que-o-modelo-vale.sql) | Sete perguntas na ordem em que uma pessoa cética faria. Começa pela única que importa: o modelo é melhor do que não ter modelo? |
| [`02-o-vazamento-de-dado.py`](notebooks/02-o-vazamento-de-dado.py) | Comete o erro de propósito, mede, e conserta. Um filtro a menos e o AUC vira **1,0000** |

O `02` é o mais importante para levar ao vivo se sobrar tempo: ele treina dois
modelos idênticos, um com o filtro de data e outro sem.

| Modelo | AUC medido |
|---|---|
| honesto | 0,8838 |
| vazado | **1,0000** |

**1,0000 não é "quase perfeito" — é perfeito.** O modelo acertou todos os 704
clientes do teste, porque 1.148 deles tinham recência negativa: a última compra
era *posterior* à data de corte. Ele não aprendeu nada; leu a resposta.

---

## 🔢 O que tem que aparecer na tela

Rodado de ponta a ponta com `seed 42`:

| Onde | Número |
|---|---|
| `features_treino` | 2.815 clientes × 22 features · 39,89% compraram nos 30 dias seguintes |
| `features_cliente` | 2.816 clientes, corte 2026-08-31 |
| **Baseline "quem comprou recente"** | **AUC 0,4329 — pior que jogar moeda** |
| **Modelo** | **AUC 0,8667 · ganho de +0,2235 sobre a melhor regra simples** |
| Feature nº 1 | **`atraso_relativo`** |
| Calibragem (holdout de 704) | Fria 11,7% → Muito quente **81,1%** compraram |
| Score | 2.816 clientes · 671 muito quentes |
| Carteira do dia | 1.290 contatos · 36 vendedores |
| Clientes grandes e atrasados | **35** |
| Receita recuperável | R$ 76.684/mês em 112 clientes |
| Pipeline | **18 tarefas · 19 testes que quebram** |

---

## 🎯 As quatro ideias que a noite defende

### 1 · A feature que vale dinheiro não vem de biblioteca

`recencia_dias` está em qualquer tutorial. **`atraso_relativo`** — recência
dividida pelo intervalo médio *do próprio cliente* — não está em nenhum, porque
depende de saber como distribuição funciona.

Um cliente que compra a cada 7 dias e sumiu há 20 está em risco. Um que compra
a cada 90 e sumiu há 20 está normal. A recência não distingue os dois.

**É a coluna que o modelo mais usa.** Foi medida por permutação, não afirmada.

### 2 · Vazamento de dado não parece erro — parece sucesso

Se a feature enxergar o que aconteceu depois do rótulo, o AUC vem 1,0000 e você
manda print no grupo. Três meses depois o modelo acerta menos que o estagiário.

Três defesas, todas estruturais:

| Defesa | Onde |
|---|---|
| Uma função só, com a data por parâmetro | `montar_features(referencia)` |
| Um teste que desconfia do sucesso | AUC ≥ 0,99 **quebra o job** |
| Uma coluna que registra o corte | `_referencia` nas duas tabelas |

O notebook `02` prova que a segunda defesa funciona: com o filtro de fora, o
AUC vai a **1,0000** e o teste 3 do pipeline derruba o job.

### 3 · Um dado errado quebra. Um modelo ruim funciona

Essa é a frase da noite.

Dado nulo explode e alguém é avisado. Modelo ruim continua devolvendo número
para todo mundo, na faixa certa, sem erro nenhum: pipeline verde, dashboard
atualizado, e o vendedor ligando para a lista errada por seis meses.

Por isso os oito testes de modelo. E o mais importante deles é o que quase
ninguém escreve: **o modelo ganha do baseline?** A pergunta certa nunca é "o
AUC está bom", é "está melhor do que o que a gente já fazia de graça".

### 4 · Score não é decisão

`0,8412` não é uma ação. A `carteira_do_dia` traduz para a língua de quem vai
ligar:

> *"Costuma comprar a cada 89 dias e está há 92 sem pedido"*
>
> *"Cliente grande e atrasado para o padrão dele — ligar hoje"*

Modelo que não explica não é usado: fica um mês na tela e some.

---

## 🗂️ Onde o código mora

O bundle é o **mesmo da noite 2** — o aluno continua no projeto que já tem:

```
aulas/aula-02-engenharia-de-dados/rotaperfume/
└── src/ml/
    ├── 11-features.py            uma função, dois cortes, duas tabelas
    ├── 12-treino.py              baseline → treino → MLflow → UC → @challenger
    ├── 13-score.py               @prod → predict_proba → gold.score_propensao
    ├── 14-testes-de-modelo.sql   8 testes que quebram o job
    ├── 15-carteira-do-dia.sql    as três views de decisão
    └── 16-promocao.py            challenger vs prod, e o histórico da decisão
```

### Como rodar

```bash
cd aulas/aula-02-engenharia-de-dados/rotaperfume
databricks bundle validate --target dev --profile jornada
databricks bundle deploy   --target dev --profile jornada
databricks bundle run rotaperfume_pipeline --target dev --profile jornada
```

> O `--profile` é o mesmo que você escolheu na noite 2. Os prompts em
> [`prd/`](prd) vêm com `projeto-dados-ia` no texto — troque pelo seu.

---

## ⚠️ Armadilhas medidas contra o workspace

Estas custaram tempo na preparação e **todas as três são específicas do Free
Edition**. Estão documentadas dentro do prompt onde aparecem.

1. **`mlflow.pyfunc.spark_udf` não funciona no serverless.** Levanta
   `InvalidVersion: '18.x-aarch64-photon-scala2'` — e é o caminho que toda a
   documentação recomenda. A saída é `load_model` + pandas. Para 2.816
   clientes, é a escolha certa de qualquer jeito: Spark serve para o que não
   cabe na memória.

2. **XGBoost treina, registra e não carrega de volta.** Conflito com o
   scikit-learn 1.6.1 do serverless (`AttributeError: __sklearn_tags__`). O
   pior tipo de erro: aparece **uma tarefa depois**. Use
   `HistGradientBoostingClassifier`, nativo do sklearn.

3. **`mlflow.set_experiment` não cria a pasta pai.** O erro é
   `BAD_REQUEST: For input string: "None"` e não menciona pasta nenhuma.
   Resolve com `WorkspaceClient().workspace.mkdirs(...)` antes.

4. **`DECIMAL` não serializa em JSON.** A gold usa `DECIMAL(18,2)`; sem
   `.cast("double")` nas features, o registro do modelo morre com
   `Object of type Decimal is not JSON serializable`.

5. **`pyfunc.predict()` devolve a classe, não a probabilidade.** A coluna
   inteira vira zeros e uns e a priorização vira sorteio. Use
   `mlflow.sklearn.load_model` + `predict_proba`.

6. **Free Edition não tem endpoint de modelo próprio** — só os Foundation
   Models já publicados. Por isso o consumo é batch. O que, para esta pergunta,
   é a arquitetura correta de qualquer forma.

### 🐛 E um bug da noite 2, encontrado aqui

`silver.visitas` marcava `gerou_pedido` comparando o resultado da visita com
`'Pedido'`, e o ERP grava `'Pedido realizado'`. **A flag era sempre falsa** —
17.502 visitas com pedido (46% do total) contadas como zero.

Nada quebrou, nada apareceu vermelho: o número simplesmente ficou zerado. É
exatamente o tipo de erro que a noite 3 existe para discutir, e ele apareceu
porque uma feature dependia dessa coluna. Já está corrigido em
[`04-crm-e-financeiro.sql`](../aula-02-engenharia-de-dados/rotaperfume/src/silver/04-crm-e-financeiro.sql).

---

## 🎬 O fechamento

> *"Segunda a gente escreveu uma query que quebrou por causa de data em dois
> formatos. Terça aquilo virou camada. Hoje o mesmo pipeline parou de responder
> o que aconteceu e passou a dizer o que fazer amanhã.*
>
> *E a coluna que mais pesa nesse modelo não veio de biblioteca nenhuma — veio
> de saber que, em distribuição, quem comprou ontem é justamente quem não
> compra hoje.*
>
> *Ciência de dados não é o algoritmo. O algoritmo tem três linhas e é igual
> para todo mundo. É saber o que perguntar, com que dado, e ter como provar que
> a resposta está certa."*
