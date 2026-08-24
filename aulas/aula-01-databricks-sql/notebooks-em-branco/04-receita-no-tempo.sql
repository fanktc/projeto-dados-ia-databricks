-- Databricks notebook source
-- MAGIC %md
-- MAGIC # Exemplo 04 · A pergunta da noite, parte 1
-- MAGIC
-- MAGIC ## "Qual foi nossa receita?"
-- MAGIC
-- MAGIC **Conceitos:** `GROUP BY`, `date_trunc`, `SUM`, `try_to_date`

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ### 1. A query ingênua — a que a gente escreveria sem olhar o dado
-- MAGIC
-- MAGIC Receita por mês, ignorando cancelados.
-- MAGIC
-- MAGIC > Dica: `date_trunc('month', data_pedido)`, `GROUP BY`, `ROUND(SUM(...), 2)`
-- MAGIC
-- MAGIC ⚠️ **Ela vai falhar.** Rode assim mesmo — o erro é a aula.

-- COMMAND ----------



-- COMMAND ----------

-- MAGIC %md
-- MAGIC ### Por que quebrou?
-- MAGIC
-- MAGIC `CAST_INVALID_INPUT`. Os 3.443 pedidos com data em `dd/MM/yyyy` não
-- MAGIC convertem, e derrubam a query inteira.
-- MAGIC
-- MAGIC Repare: **o dado sujo não deu resposta errada em silêncio — deu erro na
-- MAGIC cara.** Isso é melhor. Pior seria se tivesse respondido.

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ### 2. Agora a versão que funciona
-- MAGIC
-- MAGIC Trate os dois formatos de data e o valor que veio como texto.
-- MAGIC
-- MAGIC > Dica: `coalesce(try_to_date(col,'yyyy-MM-dd'), try_to_date(col,'dd/MM/yyyy'))`
-- MAGIC >
-- MAGIC > `try_to_date` devolve NULL em vez de quebrar. `to_date` puro **também
-- MAGIC > estoura** — teste se quiser ver.
-- MAGIC
-- MAGIC Resultado esperado: 24 meses, começando em set/2024.

-- COMMAND ----------



-- COMMAND ----------

-- MAGIC %md
-- MAGIC ### 3. Confira os números-âncora
-- MAGIC
-- MAGIC Some tudo e veja se bate:
-- MAGIC
-- MAGIC | Métrica | Esperado |
-- MAGIC |---|---|
-- MAGIC | Receita total | R$ 102.303.828,05 |
-- MAGIC | Pedidos faturados | 27.772 |
-- MAGIC | Ticket médio | R$ 3.683,70 |
-- MAGIC
-- MAGIC Se o seu número divergir muito, o erro está na query — não no dado.

-- COMMAND ----------



-- COMMAND ----------

-- MAGIC %md
-- MAGIC ### 4. Qual foi o melhor mês? E o pior?
-- MAGIC
-- MAGIC > Resultado esperado: outubro/2025 com R$ 7,0 mi · janeiro/2026 com R$ 2,5 mi
-- MAGIC
-- MAGIC **A pergunta que a turma faz:** "não era pra vender mais no Natal?"
-- MAGIC
-- MAGIC Não. A gente é distribuidora. O varejo compra **antes** da data, então o
-- MAGIC nosso pico é o mês anterior — outubro puxa a Black Friday, abril puxa o
-- MAGIC Dia das Mães. Dezembro e janeiro são vale: o varejo já está abastecido.

-- COMMAND ----------


