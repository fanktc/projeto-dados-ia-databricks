-- Databricks notebook source
-- MAGIC %md
-- MAGIC # Exemplo 06 · Onde a receita se concentra
-- MAGIC
-- MAGIC Vender mais é ganhar mais? Depende do que você vende.
-- MAGIC
-- MAGIC **Conceitos:** `JOIN` de 3 tabelas, window function, margem

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ### 1. Sazonalidade: qual mês do ano vende mais?
-- MAGIC
-- MAGIC Some a receita por mês-do-ano, numa janela de 12 meses fechados
-- MAGIC (nov/2024 a out/2025), para cada mês entrar uma vez só.
-- MAGIC
-- MAGIC > Dica: `month(...)` sobre a data já convertida, e `BETWEEN` no filtro
-- MAGIC >
-- MAGIC > Resultado esperado: outubro R$ 7,0 mi · abril R$ 6,2 mi · junho R$ 5,3 mi

-- COMMAND ----------



-- COMMAND ----------

-- MAGIC %md
-- MAGIC ⚠️ **Duas armadilhas nesta query:**
-- MAGIC
-- MAGIC 1. Setembro/2024 é o primeiro mês da base e tem o dobro de pedidos —
-- MAGIC    é carga inicial, não sazonalidade.
-- MAGIC 2. A série tem 24 meses, mas não são 2 anos redondos. Somar por
-- MAGIC    mês-do-ano sem cuidado faz um mês que aparece duas vezes ganhar de um
-- MAGIC    que aparece uma só.

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ### 2. Qual marca concentra a receita?
-- MAGIC
-- MAGIC Aqui entra o primeiro join de verdade: `itens_pedido` → `produtos`.
-- MAGIC
-- MAGIC E a primeira decisão de negócio: **excluir devolução**. Quantidade
-- MAGIC negativa é mercadoria que voltou.
-- MAGIC
-- MAGIC > Dica: participação percentual sai com `SUM(...) OVER ()`
-- MAGIC >
-- MAGIC > Resultado esperado: Layali R$ 18,6 mi · Attar Real R$ 5,2 mi

-- COMMAND ----------



-- COMMAND ----------

-- MAGIC %md
-- MAGIC ### 3. Qual categoria dá mais lucro?
-- MAGIC
-- MAGIC Receita, custo e margem % por categoria.
-- MAGIC
-- MAGIC > Dica: custo é `quantidade * custo_unitario`
-- MAGIC >
-- MAGIC > Resultado esperado: Óleo Concentrado **49,9%** · Kit Presente **33,0%**

-- COMMAND ----------



-- COMMAND ----------

-- MAGIC %md
-- MAGIC ### Vender mais nem sempre é ganhar mais
-- MAGIC
-- MAGIC Kit Presente vende quase o dobro de Óleo Concentrado e entrega **17
-- MAGIC pontos percentuais menos** de margem.
-- MAGIC
-- MAGIC É a análise que muda a conversa com o comercial: a meta não deveria ser
-- MAGIC só faturamento.

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ### 4. O gancho da noite 2: a conta que NÃO fecha
-- MAGIC
-- MAGIC Some o valor dos itens dos pedidos **cancelados**.
-- MAGIC
-- MAGIC O pedido diz que vale R$ 0,00, mas os itens dele continuam gravados com
-- MAGIC o valor cheio.
-- MAGIC
-- MAGIC > Resultado esperado: **R$ 3.586.620,37** em 6.644 itens
-- MAGIC
-- MAGIC Amanhã a gente resolve isso.

-- COMMAND ----------


