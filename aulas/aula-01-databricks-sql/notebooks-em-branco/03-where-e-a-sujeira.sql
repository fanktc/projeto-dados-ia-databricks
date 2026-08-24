-- Databricks notebook source
-- MAGIC %md
-- MAGIC # Exemplo 03 · Filtrar, e achar a sujeira
-- MAGIC
-- MAGIC **Este é o notebook mais importante do dia.**
-- MAGIC
-- MAGIC O filtro errado não dá erro: ele dá um número menor, em silêncio, e
-- MAGIC ninguém percebe.
-- MAGIC
-- MAGIC Tudo o que a gente achar aqui é o que a noite 2 vai consertar.
-- MAGIC
-- MAGIC **Conceitos:** `WHERE`, `LIKE`, `FILTER`, `COUNT DISTINCT`

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ### 1. Quantos pedidos são cancelados?
-- MAGIC
-- MAGIC > Resultado esperado: **957**

-- COMMAND ----------



-- COMMAND ----------

-- MAGIC %md
-- MAGIC ### 2. Armadilha 1 · o cancelado vem com valor zerado
-- MAGIC
-- MAGIC Compare pedidos e receita, separando cancelado de não cancelado.
-- MAGIC
-- MAGIC Repare: dá na mesma somar com ou sem eles, porque valem 0. Mas a
-- MAGIC **contagem** muda — e ticket médio é receita dividida por contagem.
-- MAGIC
-- MAGIC > Dica: `GROUP BY status = 'Cancelado'`

-- COMMAND ----------



-- COMMAND ----------

-- MAGIC %md
-- MAGIC ### 3. Armadilha 2 · a data vem em dois formatos
-- MAGIC
-- MAGIC Quantos pedidos têm a data escrita como `15/10/2025` em vez de `2025-10-15`?
-- MAGIC
-- MAGIC > Dica: `WHERE data_pedido LIKE '%/%'`
-- MAGIC >
-- MAGIC > Resultado esperado: **3.443** (12% da base)

-- COMMAND ----------



-- COMMAND ----------

-- MAGIC %md
-- MAGIC ### 4. Armadilha 3 · o CNPJ tem três formatos
-- MAGIC
-- MAGIC Puro, pontuado e com espaço em volta. O mesmo cliente escrito de três
-- MAGIC jeitos vira três clientes em qualquer contagem.
-- MAGIC
-- MAGIC Conte, na tabela de clientes: total, quantos pontuados, quantos com
-- MAGIC espaço, quantos CNPJs distintos, e quantos distintos **depois de limpar**.
-- MAGIC
-- MAGIC > Dica: `COUNT(*) FILTER (WHERE ...)` e `regexp_replace(trim(cnpj), '[^0-9]', '')`
-- MAGIC >
-- MAGIC > Resultado esperado: 3.040 linhas · 1.111 pontuados · 223 com espaço · **3.000 CNPJs reais**

-- COMMAND ----------



-- COMMAND ----------

-- MAGIC %md
-- MAGIC A diferença entre as duas últimas colunas é o tamanho do problema.
-- MAGIC São 40 clientes cadastrados duas vezes.

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ### 5. Armadilha 4 · devolução é quantidade negativa
-- MAGIC
-- MAGIC Quantos itens têm quantidade menor que zero?
-- MAGIC
-- MAGIC > Resultado esperado: **2.327**

-- COMMAND ----------


