# Databricks notebook source
# MAGIC %md
# MAGIC # ML · promoção — quem decide se o modelo novo entra
# MAGIC
# MAGIC Todo modelo envelhece. Não porque o código apodrece, mas porque **o
# MAGIC mundo muda**: entra um concorrente, muda a política de desconto, a
# MAGIC sazonalidade vira. O modelo continua respondendo com a mesma confiança
# MAGIC de sempre, e é justamente por isso que o problema demora a aparecer.
# MAGIC
# MAGIC Retreinar é fácil — é a mesma tarefa de sempre, rodando de novo. O que
# MAGIC quase ninguém escreve é a parte difícil:
# MAGIC
# MAGIC > **quem decide se o modelo novo pode substituir o que está rodando?**
# MAGIC
# MAGIC Sem essa decisão escrita em algum lugar, ela acaba acontecendo de dois
# MAGIC jeitos ruins: automática demais (todo retreino vira produção, inclusive
# MAGIC o ruim) ou manual demais (ninguém tem coragem de trocar, e o modelo de
# MAGIC 2024 segue decidindo em 2026).
# MAGIC
# MAGIC Este notebook é essa decisão, em vinte linhas.
# MAGIC
# MAGIC ## A regra
# MAGIC
# MAGIC | Situação | O que acontece |
# MAGIC |---|---|
# MAGIC | Não existe `@prod` | o challenger assume |
# MAGIC | Challenger ganha por **mais de 0,01** de AUC | promove |
# MAGIC | Diferença dentro de 0,01 | **não promove** — empate técnico não justifica troca |
# MAGIC | Challenger perde | não promove, e registra o motivo |
# MAGIC
# MAGIC A margem existe porque AUC oscila entre execuções por causa do sorteio
# MAGIC do split. Trocar o modelo de produção por causa de ruído é pior do que
# MAGIC não trocar: cada troca é uma explicação a dar quando o número muda.

# COMMAND ----------

dbutils.widgets.text("catalog", "lakehouse_rotaperfume")
catalog = dbutils.widgets.get("catalog")

MODELO = f"{catalog}.gold.propensao_compra"
MARGEM_MINIMA = 0.01

# COMMAND ----------

import json
import mlflow
from mlflow.tracking import MlflowClient
from pyspark.sql import functions as F

mlflow.set_registry_uri("databricks-uc")
cliente = MlflowClient(registry_uri="databricks-uc")

challenger = cliente.get_model_version_by_alias(MODELO, "challenger")

try:
    producao = cliente.get_model_version_by_alias(MODELO, "prod")
except Exception:
    producao = None

# COMMAND ----------
# MAGIC %md
# MAGIC ## As métricas das duas versões
# MAGIC
# MAGIC Vêm da tabela `gold.modelo_metricas`, que a tarefa de treino alimenta a
# MAGIC cada execução — uma linha por versão. Poderiam vir da API do MLflow;
# MAGIC virem de tabela é o que permite auditar a decisão em SQL depois, e é o
# MAGIC que deixa a promoção explicável para quem não usa MLflow.

# COMMAND ----------

metricas = spark.table(f"{catalog}.gold.modelo_metricas")


def auc_da_versao(versao):
    linha = (metricas.filter(F.col("versao") == int(versao))
                     .orderBy(F.desc("_treinado_em")).limit(1).collect())
    return float(linha[0]["auc"]) if linha else None


auc_challenger = auc_da_versao(challenger.version)
auc_producao = auc_da_versao(producao.version) if producao else None

print(f"challenger  versão {challenger.version}  AUC {auc_challenger}")
print(f"prod        versão {producao.version if producao else '—'}  AUC {auc_producao}")

# COMMAND ----------
# MAGIC %md
# MAGIC ## A decisão

# COMMAND ----------

if producao is None:
    promover, motivo = True, "não havia modelo em produção"
elif challenger.version == producao.version:
    promover, motivo = False, "o challenger já é o modelo em produção"
elif auc_challenger is None:
    promover, motivo = False, "o challenger não tem métrica registrada"
elif auc_producao is None:
    promover, motivo = True, "o modelo em produção não tem métrica registrada"
elif auc_challenger > auc_producao + MARGEM_MINIMA:
    promover = True
    motivo = f"AUC subiu de {auc_producao:.4f} para {auc_challenger:.4f}"
else:
    promover = False
    motivo = (f"diferença de {auc_challenger - auc_producao:+.4f} não passa a margem "
              f"de {MARGEM_MINIMA}: empate técnico não justifica troca")

if promover:
    cliente.set_registered_model_alias(MODELO, "prod", challenger.version)
    print(f"PROMOVIDO · versão {challenger.version} → @prod · {motivo}")
else:
    print(f"MANTIDO · @prod segue na versão {producao.version if producao else '—'} · {motivo}")

# COMMAND ----------
# MAGIC %md
# MAGIC ## O histórico da decisão
# MAGIC
# MAGIC Toda promoção — e toda recusa — vira linha. Daqui a seis meses, quando
# MAGIC alguém perguntar "por que o número mudou em outubro?", a resposta está
# MAGIC aqui, com data e motivo, em vez de na memória de quem estava de plantão.

# COMMAND ----------

import pandas as pd

registro = spark.createDataFrame(pd.DataFrame([{
    "modelo": MODELO,
    "versao_challenger": int(challenger.version),
    "versao_prod_anterior": int(producao.version) if producao else None,
    "auc_challenger": auc_challenger,
    "auc_prod_anterior": auc_producao,
    "promovido": bool(promover),
    "motivo": motivo,
}])).withColumn("_decidido_em", F.current_timestamp())

(registro.write.mode("append").option("mergeSchema", "true")
         .saveAsTable(f"{catalog}.gold.modelo_promocoes"))

spark.sql(f"""
  COMMENT ON TABLE {catalog}.gold.modelo_promocoes IS
  'Histórico de decisões de promoção do modelo: qual versão foi avaliada, contra qual, e por que entrou ou não em produção.'
""")

# COMMAND ----------
# MAGIC %md
# MAGIC ## E para voltar atrás?
# MAGIC
# MAGIC É a mesma linha, com outro número. Rollback de modelo não deveria ser um
# MAGIC evento — deveria ser mais fácil do que explicar por que não dá:
# MAGIC
# MAGIC ```python
# MAGIC cliente.set_registered_model_alias(MODELO, "prod", 2)   # volta para a versão 2
# MAGIC ```
# MAGIC
# MAGIC A tarefa de score lê `@prod` e passa a usar a versão 2 na próxima
# MAGIC execução, sem uma linha de código alterada em lugar nenhum. É para isso
# MAGIC que o alias existe.

# COMMAND ----------

dbutils.notebook.exit(json.dumps({
    "promovido": bool(promover),
    "motivo": motivo,
    "versao_em_prod": int(cliente.get_model_version_by_alias(MODELO, "prod").version),
}))
