# Prompt 3 · O score — o modelo sai do MLflow e vira tabela

**Entrega:** `gold.score_propensao`, uma linha por cliente, com probabilidade,
faixa e a versão do modelo que a gerou. **Deploy nº 3 da noite.**

> Um modelo registrado que ninguém consegue consultar não serve para nada. Este
> prompt fecha o circuito: o artefato do MLflow vira uma tabela Delta na gold,
> que dashboard, Genie e vendedor leem como leriam qualquer outra.

---

## O que mostrar antes

**1 · O modelo existe e é inútil**

```bash
databricks registered-models get lakehouse_rotaperfume.gold.propensao_compra \
  --profile projeto-dados-ia
```

> *"O modelo está no catálogo, versionado, com linhagem. E o vendedor não
> consegue fazer nada com ele — não existe tela de MLflow no celular de quem
> está na rua. Modelo só vira útil quando vira linha de tabela."*

**2 · A pergunta que a gold ainda não responde**

```sql
-- ninguém consegue responder isso hoje
SELECT * FROM lakehouse_rotaperfume.gold.score_propensao LIMIT 5;
-- TABLE_OR_VIEW_NOT_FOUND
```

**3 · A decisão de arquitetura, feita na tela**

Desenhe as duas opções e escolha na frente da sala:

| | Batch (o que vamos fazer) | Endpoint de tempo real |
|---|---|---|
| Quando responde | uma vez por dia | em 50ms, a cada chamada |
| Custo | roda e desliga | infraestrutura ligada 24h |
| Serve para | a rota do vendedor amanhã | fraude na autorização, recomendação no clique |

> *"A pergunta da noite é 'com quem eu falo amanhã de manhã'. Isso muda uma vez
> por dia. Ninguém precisa de resposta em 50 milissegundos para montar uma
> rota. Endpoint aqui seria pagar infraestrutura ligada a semana inteira para
> responder uma pergunta que só muda de manhã."*
>
> E a parte honesta: *"além disso, o Free Edition não oferece endpoint de
> modelo próprio — só os Foundation Models já publicados. A escolha é técnica e
> também é o que a conta permite. Vale dizer as duas coisas."*

---

**Enquanto ele trabalha, você explica:**

- **A pegadinha que vale a tarefa inteira:** `pyfunc.predict()` num
  classificador devolve **a classe** (0 ou 1), não a probabilidade. Quem
  escreve isso sem conferir recebe uma coluna de zeros e uns achando que tem
  score — e a priorização vira um sorteio entre 700 clientes empatados em 1.
  Por isso: `mlflow.sklearn.load_model()` + `predict_proba()`.
- **`@prod`, nunca o número da versão.** A tarefa de score não sabe qual versão
  está rodando, e é isso que faz o rollback do prompt 6 custar um comando.
- **A tabela guarda a versão que a gerou.** É o que permite responder, seis
  meses depois, "por que este cliente estava na lista em setembro?" — em vez de
  "não sei, o modelo mudou desde então".
- **A faixa existe para o número virar conversa.** Ninguém age sobre `0,7431`.
  *Quente* é uma palavra que o vendedor já usa. O score continua na coluna ao
  lado para quem quiser ordenar fino.

---

## O prompt

```
Continue o bundle em aulas/aula-02-engenharia-de-dados/rotaperfume/.
O modelo lakehouse_rotaperfume.gold.propensao_compra está registrado com
alias @prod, e gold.features_cliente tem 2.816 clientes sem rótulo.

1. src/ml/13-score.py — notebook Python (serverless).

   a) Carregue o modelo por ALIAS: models:/<catalogo>.gold.propensao_compra@prod
      Nunca pelo número da versão — é o alias que torna o rollback trivial.
      Use mlflow.sklearn.load_model, NÃO mlflow.pyfunc.load_model:
      pyfunc.predict() num classificador devolve a CLASSE (0/1), não a
      probabilidade, e a coluna inteira vira zeros e uns.

   b) Pegue a lista de colunas de modelo.feature_names_in_ e valide com assert
      que gold.features_cliente tem todas. Se a lista divergir, o erro tem que
      aparecer aqui — não numa priorização silenciosamente errada.

   c) score = modelo.predict_proba(X)[:, 1]

   d) Traduza em faixa: até 0,30 Fria; até 0,60 Morna; até 0,80 Quente;
      acima disso Muito quente.

   e) Grave gold.score_propensao (overwrite) com cliente_id, score_propensao,
      faixa, o nome do modelo, a VERSÃO apontada por @prod no momento do
      cálculo, e _pontuado_em.

   f) COMMENT ON TABLE e COMMENT em todas as colunas — a tarefa
      auditoria_de_metadado de ontem quebra o job se faltar, e o score é gold
      como qualquer outra tabela.

   g) dbutils.notebook.exit com a versão, o total pontuado e a contagem por
      faixa.

2. Acrescente a tarefa ml_score ao pipeline, depois de ml_treino.

3. Rode validate, deploy e run com --profile projeto-dados-ia.
```

---

## Como verificar a feature

**1 · A tabela existe e todo mundo tem score**

```sql
SELECT COUNT(*) AS pontuados,
       COUNT(DISTINCT versao_modelo) AS versoes,
       MAX(_pontuado_em) AS quando
FROM lakehouse_rotaperfume.gold.score_propensao;
-- 2.816 · 1 versão
```

**2 · O score é uma probabilidade de verdade — a checagem da pegadinha**

```sql
SELECT ROUND(MIN(score_propensao), 4) AS minimo,
       ROUND(MAX(score_propensao), 4) AS maximo,
       COUNT(DISTINCT score_propensao) AS valores_distintos
FROM lakehouse_rotaperfume.gold.score_propensao;
-- milhares de valores distintos entre 0 e 1.
-- Se der 2 valores distintos, alguém usou predict() no lugar de predict_proba().
```

**3 · A distribuição por faixa**

```sql
SELECT faixa, COUNT(*) AS clientes,
       ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1) AS pct
FROM lakehouse_rotaperfume.gold.score_propensao
GROUP BY faixa ORDER BY clientes DESC;
```

| Faixa | Clientes | % |
|---|---|---|
| Fria | 1.281 | 45,5% |
| Muito quente | 671 | 23,8% |
| Morna | 513 | 18,2% |
| Quente | 351 | 12,5% |

> *"Quase metade da base está fria, e 671 clientes estão muito quentes. Repare
> que isso já é uma decisão de negócio: são 671 conversas que valem a pena
> começar amanhã, de uma base de 2.816. Sem isso, o vendedor liga na ordem
> alfabética."*

**4 · A tabela sabe de onde veio**

```sql
SELECT DISTINCT modelo, versao_modelo FROM lakehouse_rotaperfume.gold.score_propensao;
```

> *"A tabela carrega a versão do modelo que a gerou. Parece burocracia até o dia
> em que alguém pergunta por que a lista de setembro estava diferente — e você
> responde com uma query em vez de um encolher de ombros."*

**5 · O metadado continua auditado**

```sql
SELECT column_name, comment
FROM lakehouse_rotaperfume.information_schema.columns
WHERE table_schema = 'gold' AND table_name = 'score_propensao'
ORDER BY ordinal_position;
-- todas comentadas. A tarefa auditoria_de_metadado segue verde.
```

---

## Se der errado ao vivo

| Sintoma | Causa | Correção em um prompt |
|---|---|---|
| Só existem 2 valores distintos de score | `pyfunc.predict()` devolveu a classe | Troque para `mlflow.sklearn.load_model` + `predict_proba` |
| `InvalidVersion: '18.x-aarch64-photon-scala2'` | `mlflow.pyfunc.spark_udf` não funciona no serverless do Free Edition | Use `load_model` + pandas: 2.816 clientes cabem na memória |
| `RESOURCE_DOES_NOT_EXIST … @prod` | O alias não foi apontado no prompt 2 | `client.set_registered_model_alias(MODELO, "prod", 1)` |
| `AttributeError: __sklearn_tags__` | O modelo foi treinado com XGBoost | Conflito de versão do Free Edition — treine com `HistGradientBoostingClassifier` |
| O `assert` das colunas falha | `features_cliente` e `features_treino` divergiram | As duas têm que sair da MESMA função. É o ponto do prompt 1 |

**Tempo medido:** ~50 segundos.

---

## O que fica de pé

| Objeto | O quê |
|---|---|
| `gold.score_propensao` | 2.816 clientes com probabilidade, faixa e versão do modelo |
| Job | `rotaperfume_pipeline` com 15 tarefas |
