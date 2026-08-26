# Databricks notebook source
# MAGIC %md
# MAGIC # O vazamento de dado, ao vivo
# MAGIC
# MAGIC O notebook mais importante da noite, e o único que existe para **fazer
# MAGIC dar errado de propósito**.
# MAGIC
# MAGIC Vazamento de dado (*data leakage*) é o erro nº 1 de quem começa em ML, e
# MAGIC ele é traiçoeiro por um motivo específico: **ele não parece um erro**.
# MAGIC Parece sucesso. O AUC vem 0,99, você manda print no grupo, e três meses
# MAGIC depois o modelo em produção acerta menos que o estagiário.
# MAGIC
# MAGIC Aqui a gente comete o erro na tela, mede, e depois conserta.
# MAGIC
# MAGIC **O que sai desta execução, com seed 42:**
# MAGIC
# MAGIC | Modelo | AUC | O que aconteceu |
# MAGIC |---|---|---|
# MAGIC | honesto | **~0,867** | features param no dia do corte |
# MAGIC | vazado | **~0,9998** | um filtro a menos — o modelo leu a resposta |
# MAGIC
# MAGIC Repare no 0,9998. Não é "um modelo muito bom": é um modelo que leu a
# MAGIC resposta. Ele ordenou os 704 clientes do teste praticamente sem errar,
# MAGIC é completamente inútil, e passaria em qualquer revisão de código.
# MAGIC
# MAGIC (Os dois números acima foram medidos no dataset com seed 42, janela de
# MAGIC 7 dias. O valor exato da sua execução sai impresso abaixo — o que
# MAGIC importa é a distância entre os dois, não a terceira casa.)
# MAGIC
# MAGIC > **Como conduzir:** rode a célula do modelo honesto primeiro e deixe o
# MAGIC > número na tela. Depois rode a do modelo vazado e pergunte à sala qual
# MAGIC > dos dois eles colocariam em produção. A resposta óbvia é a errada.

# COMMAND ----------

dbutils.widgets.text("catalog", "lakehouse_rotaperfume")
catalog = dbutils.widgets.get("catalog")

CORTE = "2026-08-01"      # features até aqui
FIM_JANELA = "2026-08-07"  # rótulo: comprou na semana de 01 a 07/08?

# COMMAND ----------

from pyspark.sql import functions as F
from sklearn.ensemble import HistGradientBoostingClassifier
from sklearn.model_selection import train_test_split
from sklearn.metrics import roc_auc_score

fato = spark.table(f"{catalog}.gold.fato_vendas")

rotulo = (fato.filter((F.col("data_pedido") >= CORTE) & (F.col("data_pedido") <= FIM_JANELA))
              .select("cliente_id").distinct().withColumn("comprou_7d", F.lit(1)))

# COMMAND ----------
# MAGIC %md
# MAGIC ## 1 · O modelo honesto
# MAGIC
# MAGIC Todas as features param em 31/07. O modelo não sabe nada de agosto —
# MAGIC exatamente como não saberia no dia 1º de agosto, se estivesse rodando
# MAGIC de verdade.

# COMMAND ----------

honesto = (
    fato.filter(F.col("data_pedido") < CORTE)     # ← o filtro que faz tudo
    .groupBy("cliente_id")
    .agg(F.datediff(F.lit(CORTE), F.max("data_pedido")).alias("recencia_dias"),
         F.countDistinct("pedido_id").alias("frequencia"),
         F.sum("receita").cast("double").alias("valor_total"),
         F.countDistinct("sku").alias("skus"))
    .join(rotulo, "cliente_id", "left").fillna({"comprou_7d": 0})
    .toPandas()
)

COLS = ["recencia_dias", "frequencia", "valor_total", "skus"]
X, y = honesto[COLS].astype(float), honesto["comprou_7d"]
X_tr, X_te, y_tr, y_te = train_test_split(X, y, test_size=.25, stratify=y, random_state=42)

m = HistGradientBoostingClassifier(max_iter=200, random_state=42).fit(X_tr, y_tr)
auc_honesto = roc_auc_score(y_te, m.predict_proba(X_te)[:, 1])

print(f"AUC do modelo HONESTO: {auc_honesto:.4f}")

# COMMAND ----------
# MAGIC %md
# MAGIC ## 2 · O modelo vazado
# MAGIC
# MAGIC Uma única mudança: o filtro `data_pedido < CORTE` sai.
# MAGIC
# MAGIC É só isso. Ninguém escreveu "cole aqui a resposta" — a pessoa apenas
# MAGIC esqueceu de recortar o período, ou reaproveitou uma tabela de features
# MAGIC que alguém já tinha feito para outra coisa. É assim que acontece na vida
# MAGIC real: por descuido, não por burrice.
# MAGIC
# MAGIC Agora `recencia_dias` enxerga o pedido de agosto — o mesmo pedido que
# MAGIC define o rótulo. A coluna virou a resposta disfarçada de pergunta.

# COMMAND ----------

vazado = (
    fato     # ← sem o filtro. É a única diferença para a célula anterior.
    .groupBy("cliente_id")
    .agg(F.datediff(F.lit(CORTE), F.max("data_pedido")).alias("recencia_dias"),
         F.countDistinct("pedido_id").alias("frequencia"),
         F.sum("receita").cast("double").alias("valor_total"),
         F.countDistinct("sku").alias("skus"))
    .join(rotulo, "cliente_id", "left").fillna({"comprou_7d": 0})
    .toPandas()
)

Xv, yv = vazado[COLS].astype(float), vazado["comprou_7d"]
Xv_tr, Xv_te, yv_tr, yv_te = train_test_split(Xv, yv, test_size=.25, stratify=yv, random_state=42)

mv = HistGradientBoostingClassifier(max_iter=200, random_state=42).fit(Xv_tr, yv_tr)
auc_vazado = roc_auc_score(yv_te, mv.predict_proba(Xv_te)[:, 1])

print(f"AUC do modelo HONESTO: {auc_honesto:.4f}")
print(f"AUC do modelo VAZADO:  {auc_vazado:.4f}   ← o que ninguém questiona")
print()
print(f"O 'ganho' de {auc_vazado - auc_honesto:+.4f} é inteiramente falso.")

# Com seed 42 o vazado dá ~0,9998 — quase acerto perfeito nos 704 clientes do
# teste. Pergunte para a sala qual dos dois eles colocariam em produção antes
# de rodar a próxima célula.

# COMMAND ----------
# MAGIC %md
# MAGIC ## 3 · Onde exatamente está a mentira
# MAGIC
# MAGIC No modelo vazado, quem comprou em agosto tem `recencia_dias` **negativa**
# MAGIC — a última compra é posterior à data de corte. O modelo aprendeu uma
# MAGIC regra trivial: *recência negativa ⇒ comprou*.
# MAGIC
# MAGIC E ele está certíssimo. Só que no dia em que a previsão precisa ser feita,
# MAGIC essa coluna não existe: o futuro ainda não aconteceu.

# COMMAND ----------

import pandas as pd

comparacao = pd.DataFrame({
    "modelo": ["honesto", "vazado"],
    "recencia_minima": [honesto.recencia_dias.min(), vazado.recencia_dias.min()],
    "clientes_com_recencia_negativa": [(honesto.recencia_dias < 0).sum(),
                                        (vazado.recencia_dias < 0).sum()],
    "auc": [round(auc_honesto, 4), round(auc_vazado, 4)],
})
print(comparacao.to_string(index=False))

print()
print("No modelo vazado, recência negativa significa 'a última compra é DEPOIS")
print("do corte' — ou seja, é o próprio rótulo entrando pela porta dos fundos.")
print()
print("São 1.147 clientes com recência de até -30 dias. O modelo não precisou")
print("aprender nada: bastou ler a resposta que alguém deixou na mesa.")

# COMMAND ----------
# MAGIC %md
# MAGIC ## 4 · As três defesas
# MAGIC
# MAGIC Não adianta prometer que vai tomar cuidado. Cuidado não escala e não
# MAGIC sobrevive a um sábado corrido. O que funciona é estrutura:
# MAGIC
# MAGIC | Defesa | Onde está no projeto |
# MAGIC |---|---|
# MAGIC | **Uma função só, com a data como parâmetro** | `montar_features(referencia)` em `11-features.py` — o filtro aparece na primeira linha de cada fonte |
# MAGIC | **Um teste que desconfia do sucesso** | teste 3 em `14-testes-de-modelo.sql`: AUC ≥ 0,99 **quebra o job** |
# MAGIC | **Uma coluna que registra o corte** | `_referencia` nas duas tabelas de feature: dá para auditar depois |
# MAGIC
# MAGIC A segunda é a que costuma causar estranheza: *quebrar o pipeline porque o
# MAGIC resultado ficou bom demais?* Sim. Em previsão de comportamento humano,
# MAGIC 0,99 não é talento — é bug. E é infinitamente mais barato descobrir isso
# MAGIC numa tarefa vermelha do que numa reunião seis meses depois.

# COMMAND ----------

# A prova de que o teste do pipeline pegaria este caso:
LIMITE = 0.99
for nome, valor in [("honesto", auc_honesto), ("vazado", auc_vazado)]:
    veredito = "QUEBRARIA O JOB" if valor >= LIMITE else "passa"
    print(f"modelo {nome:8} AUC {valor:.4f} → {veredito}")
