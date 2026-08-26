# Databricks notebook source
# MAGIC %md
# MAGIC # ML · o score em batch
# MAGIC
# MAGIC O modelo está registrado no Unity Catalog e ninguém consegue usar ele
# MAGIC ainda. Esta tarefa fecha o circuito: carrega o `@prod`, pontua os 3.000
# MAGIC clientes e grava **uma tabela Delta na gold** — que dashboard, Genie e
# MAGIC vendedor consultam como consultariam qualquer outra.
# MAGIC
# MAGIC ## Por que batch, e não um endpoint de tempo real
# MAGIC
# MAGIC A pergunta "com quem eu falo amanhã de manhã" é respondida **uma vez por
# MAGIC dia**. Ninguém precisa de resposta em 50ms para montar a rota do
# MAGIC vendedor. Endpoint de serving existe para decidir no clique — fraude na
# MAGIC autorização, recomendação no carregamento da página. Aqui seria
# MAGIC infraestrutura ligada 24h para responder uma pergunta que muda de manhã.
# MAGIC
# MAGIC (E, na prática: o **Free Edition não oferece** endpoint de modelo
# MAGIC próprio. Só os Foundation Models já publicados. A escolha é técnica e
# MAGIC também é o que a conta permite — vale dizer as duas coisas ao vivo.)
# MAGIC
# MAGIC ## A pegadinha desta tarefa
# MAGIC
# MAGIC `mlflow.pyfunc.load_model(...).predict()` num classificador devolve a
# MAGIC **classe** (0 ou 1), não a probabilidade. Quem escreve isso sem olhar
# MAGIC recebe uma coluna de zeros e uns achando que tem score — e a priorização
# MAGIC vira um sorteio entre 1.400 clientes empatados em 1.
# MAGIC
# MAGIC Por isso aqui é `mlflow.sklearn.load_model()` + `predict_proba()`.

# COMMAND ----------

dbutils.widgets.text("catalog", "lakehouse_rotaperfume")
catalog = dbutils.widgets.get("catalog")

MODELO = f"{catalog}.gold.propensao_compra"

# COMMAND ----------

import json
import mlflow
import pandas as pd
from mlflow.tracking import MlflowClient
from pyspark.sql import functions as F

mlflow.set_registry_uri("databricks-uc")

# `@prod` em vez do número da versão: quando o prompt 6 promover um challenger,
# esta linha continua igual. Consumidor não deveria saber número de versão.
versao = MlflowClient(registry_uri="databricks-uc").get_model_version_by_alias(MODELO, "prod")
modelo = mlflow.sklearn.load_model(f"models:/{MODELO}@prod")

print(f"carregado {MODELO} versão {versao.version} (alias @prod)")

# COMMAND ----------
# MAGIC %md
# MAGIC ## As colunas do score têm que ser as do treino
# MAGIC
# MAGIC Na mesma ordem, com os mesmos nomes. Este é o motivo de existir uma
# MAGIC função `montar_features()` só: a `features_cliente` foi gerada pela
# MAGIC mesma linha de código que gerou a `features_treino`, mudando apenas a
# MAGIC data. Se fossem dois SQLs separados, um dia divergiriam em silêncio.
# MAGIC
# MAGIC A `assert` abaixo é barata e transforma esse silêncio em erro.

# COMMAND ----------

FEATURES = list(modelo.feature_names_in_)

atual = spark.table(f"{catalog}.gold.features_cliente").toPandas()
faltando = [c for c in FEATURES if c not in atual.columns]
assert not faltando, f"features_cliente não tem as colunas do treino: {faltando}"

X = atual[FEATURES].astype(float)
atual["score_propensao"] = modelo.predict_proba(X)[:, 1]

# COMMAND ----------
# MAGIC %md
# MAGIC ## De probabilidade para faixa
# MAGIC
# MAGIC Ninguém no comercial vai agir sobre "0,7431". A faixa existe para o
# MAGIC número virar conversa: *quente* é uma palavra que o vendedor já usa.
# MAGIC
# MAGIC O score continua na tabela ao lado — quem quiser ordenar fino, ordena.

# COMMAND ----------

FAIXAS = [-0.01, 0.30, 0.60, 0.80, 1.01]
NOMES = ["Fria", "Morna", "Quente", "Muito quente"]

atual["faixa"] = pd.cut(atual["score_propensao"], FAIXAS, labels=NOMES).astype(str)

score = (
    spark.createDataFrame(atual[["cliente_id", "score_propensao", "faixa"]])
    .withColumn("modelo", F.lit(MODELO))
    .withColumn("versao_modelo", F.lit(int(versao.version)))
    .withColumn("_pontuado_em", F.current_timestamp())
)

(score.write.mode("overwrite").option("overwriteSchema", "true")
      .saveAsTable(f"{catalog}.gold.score_propensao"))

# COMMAND ----------
# MAGIC %md
# MAGIC ## O metadado, porque a auditoria de ontem continua valendo
# MAGIC
# MAGIC A tarefa `auditoria_de_metadado` do prompt 6 quebra o job se achar
# MAGIC coluna sem `COMMENT` na gold. O score é gold. Sem exceção — e é bom que
# MAGIC seja assim: é este texto que o Genie vai ler para responder "quem tem
# MAGIC mais chance de comprar".

# COMMAND ----------

spark.sql(f"""
  COMMENT ON TABLE {catalog}.gold.score_propensao IS
  'Probabilidade de cada cliente fazer pedido nos próximos 30 dias, calculada pelo modelo de propensão. Uma linha por cliente, regravada a cada execução do pipeline.'
""")

COMENTARIOS = {
    "cliente_id": "Identificador do cliente. Liga com gold.dim_cliente.",
    "score_propensao": "Probabilidade de 0 a 1 de o cliente fazer pedido nos próximos 30 dias. Quanto maior, mais prioritário o contato.",
    "faixa": "Leitura do score em palavra: Fria até 0,3; Morna até 0,6; Quente até 0,8; Muito quente acima disso.",
    "modelo": "Nome completo do modelo no Unity Catalog que gerou este score.",
    "versao_modelo": "Versão do modelo apontada pelo alias @prod no momento do cálculo. É o que permite explicar um score antigo.",
    "_pontuado_em": "Momento em que o score foi calculado. Coluna técnica.",
}
for coluna, texto in COMENTARIOS.items():
    spark.sql(f"ALTER TABLE {catalog}.gold.score_propensao ALTER COLUMN {coluna} COMMENT '{texto}'")

# COMMAND ----------

resumo = (spark.table(f"{catalog}.gold.score_propensao")
          .groupBy("faixa").agg(F.count("*").alias("clientes"))
          .orderBy(F.desc("clientes")))
resumo.show(truncate=False)

dbutils.notebook.exit(json.dumps({
    "versao_modelo": int(versao.version),
    "clientes_pontuados": int(spark.table(f"{catalog}.gold.score_propensao").count()),
    "faixas": {r["faixa"]: r["clientes"] for r in resumo.collect()},
}))
