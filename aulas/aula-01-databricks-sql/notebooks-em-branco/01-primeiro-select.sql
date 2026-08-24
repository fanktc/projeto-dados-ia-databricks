-- Databricks notebook source
-- MAGIC %md
-- MAGIC # Exemplo 01 · Olhar o que existe
-- MAGIC
-- MAGIC Primeiro dia de trabalho. Ninguém te deu documentação.
-- MAGIC
-- MAGIC Antes de escrever a query bonita, o analista olha o dado.
-- MAGIC
-- MAGIC **Conceitos:** `SELECT`, `FROM`, `LIMIT`, `DESCRIBE`

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
-- MAGIC ### 1. Como são as primeiras linhas de pedidos?
-- MAGIC
-- MAGIC São 28.729 pedidos. Você não quer todos na tela — quer entender o formato.
-- MAGIC
-- MAGIC > Dica: `SELECT`, `FROM`, `LIMIT`

-- COMMAND ----------



-- COMMAND ----------

-- MAGIC %md
-- MAGIC ### 2. Que tipo tem cada coluna?
-- MAGIC
-- MAGIC Olhe com atenção o tipo de `valor_total` e de `data_pedido`.
-- MAGIC Não é o que você esperaria — e é de propósito.
-- MAGIC
-- MAGIC > Dica: `DESCRIBE TABLE`

-- COMMAND ----------



-- COMMAND ----------

-- MAGIC %md
-- MAGIC **Por que tudo é texto?**
-- MAGIC
-- MAGIC Porque a bronze guarda o dado como veio. Se o Spark tivesse adivinhado o
-- MAGIC tipo, ele erraria as datas que vêm em dois formatos e o CNPJ perderia os
-- MAGIC zeros à esquerda. A sujeira sumiria antes de a gente ver que existe.

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ### 3. Quantas linhas tem a tabela?
-- MAGIC
-- MAGIC A pergunta mais básica, e a mais esquecida.
-- MAGIC
-- MAGIC > Resultado esperado: **28.729**

-- COMMAND ----------



-- COMMAND ----------

-- MAGIC %md
-- MAGIC ### 4. E se eu quiser só as colunas que interessam?
-- MAGIC
-- MAGIC `SELECT *` serve para explorar. Em query de verdade, peça o que precisa:
-- MAGIC é mais rápido e deixa claro para quem lê o que importa ali.

-- COMMAND ----------


