-- Databricks notebook source
-- MAGIC %md
-- MAGIC # Exemplo 05 · A pergunta da noite, parte 2
-- MAGIC
-- MAGIC ## "Quem são os melhores clientes?"
-- MAGIC
-- MAGIC **Conceitos:** `JOIN`, `GROUP BY`, `COUNT(DISTINCT)`

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ### Antes de começar: escolha o schema
-- MAGIC
-- MAGIC Rode a célula abaixo. Depois disso as queries podem ser escritas sem
-- MAGIC prefixo — `FROM pedidos` em vez de `FROM rota_perfume.bronze_aovivo.pedidos`.
-- MAGIC
-- MAGIC Para trabalhar no ambiente já pronto, troque `bronze_aovivo` por `bronze`.

-- COMMAND ----------

USE CATALOG rota_perfume;
USE SCHEMA bronze_aovivo;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ### 1. Top 10 clientes por receita
-- MAGIC
-- MAGIC Junte pedidos com clientes e agrupe por **nome**.
-- MAGIC
-- MAGIC > Dica: `JOIN ... ON c.cliente_id = p.cliente_id`, `GROUP BY razao_social, segmento`
-- MAGIC
-- MAGIC A query roda e devolve uma lista bonita. Guarde o nome do primeiro colocado.

-- COMMAND ----------



-- COMMAND ----------

-- MAGIC %md
-- MAGIC ### 2. Agora agrupe por cliente_id em vez de nome
-- MAGIC
-- MAGIC Compare o topo das duas listas.

-- COMMAND ----------



-- COMMAND ----------

-- MAGIC %md
-- MAGIC ### O "melhor cliente" da primeira query não existe
-- MAGIC
-- MAGIC Razão social **não é chave**. Existem clientes diferentes com o mesmo
-- MAGIC nome, e agrupar por nome funde todos eles numa linha só — inventando um
-- MAGIC cliente gigante que não existe.
-- MAGIC
-- MAGIC | | 1º colocado |
-- MAGIC |---|---|
-- MAGIC | Agrupando por nome | ~60 pedidos, R$ 423 mil |
-- MAGIC | Agrupando por `cliente_id` | 27 pedidos, R$ 253 mil |

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ### 3. Quantos clientes somem ao agrupar por nome?
-- MAGIC
-- MAGIC Compare `COUNT(DISTINCT cliente_id)` com `COUNT(DISTINCT razao_social)`.

-- COMMAND ----------



-- COMMAND ----------

-- MAGIC %md
-- MAGIC ### E isso ainda não resolve o problema de verdade
-- MAGIC
-- MAGIC Os 40 clientes duplicados têm `cliente_id` **diferente** e o mesmo CNPJ.
-- MAGIC Continuam contados em dobro mesmo agrupando por id.
-- MAGIC
-- MAGIC Só a deduplicação por CNPJ resolve — e ela é a noite 2.

-- COMMAND ----------


