-- Databricks notebook source
-- MAGIC %md
-- MAGIC # Exemplo 02 · Achar o extremo
-- MAGIC
-- MAGIC Depois de saber o que existe, o analista procura o extremo. É onde mora
-- MAGIC tanto a informação boa quanto o erro de cadastro.
-- MAGIC
-- MAGIC **Conceitos:** `ORDER BY`, `DESC`, `DISTINCT`, `CAST`

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ### 1. Qual foi o maior pedido?
-- MAGIC
-- MAGIC ⚠️ Cuidado: `valor_total` é **texto**. Texto ordena em ordem alfabética,
-- MAGIC onde `'9'` vem depois de `'10'`.
-- MAGIC
-- MAGIC > Dica: `ORDER BY CAST(... AS DECIMAL(18,2)) DESC`

-- COMMAND ----------



-- COMMAND ----------

-- MAGIC %md
-- MAGIC ### 2. Agora rode a mesma query SEM o CAST
-- MAGIC
-- MAGIC Compare os dois resultados. O "maior" pedido sem CAST é o que começa com
-- MAGIC o dígito mais alto, não o de maior valor.
-- MAGIC
-- MAGIC Esse é o tipo de erro que não dá mensagem — só dá o número errado.

-- COMMAND ----------



-- COMMAND ----------

-- MAGIC %md
-- MAGIC ### 3. Que valores existem na coluna status?
-- MAGIC
-- MAGIC Você precisa saber o que tem antes de escrever o `WHERE`.
-- MAGIC É assim que se descobre que existe `'Cancelado'`.
-- MAGIC
-- MAGIC > Dica: `SELECT DISTINCT`

-- COMMAND ----------



-- COMMAND ----------

-- MAGIC %md
-- MAGIC ### 4. E quantas vezes cada status aparece?
-- MAGIC
-- MAGIC Melhor que `DISTINCT` puro: a contagem de cada um.
-- MAGIC
-- MAGIC > Resultado esperado: **957 cancelados**

-- COMMAND ----------


