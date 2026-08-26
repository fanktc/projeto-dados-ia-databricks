# Databricks notebook source
# MAGIC %md
# MAGIC # ML · treino, MLflow e registro no Unity Catalog
# MAGIC
# MAGIC O modelo em si são dez linhas. O que importa nesta tarefa é o que
# MAGIC acontece **em volta** dele:
# MAGIC
# MAGIC | O que | Por que importa |
# MAGIC |---|---|
# MAGIC | MLflow registra cada treino | daqui a três meses alguém pergunta "por que o número mudou?" |
# MAGIC | O modelo é registrado no **Unity Catalog** | ele vira objeto de catálogo, com `GRANT` e linhagem, igual a uma tabela |
# MAGIC | O alias `@prod` aponta para uma versão | promover é um comando, e voltar atrás também |
# MAGIC | O **baseline** é medido antes | sem ele você não sabe se o modelo ajudou ou só ficou complicado |
# MAGIC
# MAGIC ## O baseline vem primeiro, e é ele que dá a régua
# MAGIC
# MAGIC Antes de treinar qualquer coisa, medimos a regra que o gerente comercial
# MAGIC usaria de graça: **ordenar por recência**. Se o modelo não ganhar dela,
# MAGIC ele não deveria existir — e o teste do prompt 4 vai cobrar exatamente
# MAGIC isso, quebrando o job.

# COMMAND ----------

dbutils.widgets.text("catalog", "lakehouse_rotaperfume")
catalog = dbutils.widgets.get("catalog")

MODELO = f"{catalog}.gold.propensao_compra"

# O experimento fica na pasta do próprio usuário — assim cada aluno tem o dele,
# sem depender de permissão em /Shared.
#
# ARMADILHA: `mlflow.set_experiment()` NÃO cria a pasta pai. Se ela não existir,
# o erro que volta é `BAD_REQUEST: For input string: "None"` — que não diz nada
# sobre pasta e custa vinte minutos para quem nunca viu.
from databricks.sdk import WorkspaceClient

usuario = spark.sql("SELECT current_user()").first()[0]
PASTA = f"/Users/{usuario}/rotaperfume"
EXPERIMENTO = f"{PASTA}/propensao_compra"

WorkspaceClient().workspace.mkdirs(PASTA)

# COMMAND ----------

import json
import mlflow
import numpy as np
import pandas as pd
from mlflow.tracking import MlflowClient
from sklearn.ensemble import HistGradientBoostingClassifier
from sklearn.metrics import roc_auc_score, average_precision_score, classification_report
from sklearn.model_selection import train_test_split

# 2.815 clientes cabem folgadamente na memória de um nó. Trazer para o pandas
# aqui é a escolha certa — Spark serve para o que não cabe, e forçar Spark onde
# não precisa só deixa o código mais difícil de ler ao vivo.
dados = spark.table(f"{catalog}.gold.features_treino").toPandas()

FEATURES = [c for c in dados.columns if c not in ("cliente_id", "comprou_30d", "_referencia")]
X = dados[FEATURES].astype(float)
y = dados["comprou_30d"]

X_tr, X_te, y_tr, y_te = train_test_split(X, y, test_size=0.25, stratify=y, random_state=42)

print(f"{len(dados)} clientes · {y.mean():.1%} compraram nos 30 dias seguintes")
print(f"{len(FEATURES)} features · treino {len(X_tr)} · teste {len(X_te)}")

# COMMAND ----------
# MAGIC %md
# MAGIC ## 1 · O baseline — a regra de graça
# MAGIC
# MAGIC "Ligue para quem comprou mais recentemente." É o que qualquer um faria
# MAGIC sem modelo nenhum, e é a régua honesta.
# MAGIC
# MAGIC **Prepare-se para uma surpresa nesta célula.** O número que sai aqui é o
# MAGIC argumento mais forte da noite inteira.

# COMMAND ----------

# AUC 0,5 é jogar moeda. Abaixo disso, a regra está invertida: seguir o
# contrário dela seria melhor.
baseline_recencia = roc_auc_score(y_te, -X_te["recencia_dias"])
baseline_frequencia = roc_auc_score(y_te, X_te["frequencia_pedidos"])

print(f"AUC ordenando por recência    {baseline_recencia:.4f}")
print(f"AUC ordenando por frequência  {baseline_frequencia:.4f}")
print(f"AUC de jogar uma moeda        0.5000")

# O melhor dos dois é a régua que o modelo tem que superar.
BASELINE = max(baseline_recencia, baseline_frequencia)

# COMMAND ----------
# MAGIC %md
# MAGIC ## 2 · O treino
# MAGIC
# MAGIC `HistGradientBoostingClassifier` é gradient boosting nativo do
# MAGIC scikit-learn: rápido, aceita `NaN` sem reclamar e **já vem instalado no
# MAGIC serverless**. XGBoost treinaria igual, mas exigiria declarar a
# MAGIC dependência no job e, na versão que o Free Edition traz hoje, o modelo
# MAGIC treina e registra mas **não carrega de volta** — o que só se descobre na
# MAGIC tarefa seguinte. Escolha deliberada: menos dependência, menos surpresa
# MAGIC ao vivo.
# MAGIC
# MAGIC `mlflow.autolog()` grava parâmetros, métricas e o artefato sozinho.

# COMMAND ----------

mlflow.set_registry_uri("databricks-uc")   # sem isto o modelo vai para o registro ANTIGO, fora do UC
mlflow.set_experiment(EXPERIMENTO)
mlflow.sklearn.autolog(log_models=False)   # o log do modelo é explícito, logo abaixo

with mlflow.start_run(run_name="propensao_compra") as run:
    modelo = HistGradientBoostingClassifier(
        max_iter=200, learning_rate=0.08, max_depth=5,
        min_samples_leaf=20, random_state=42,
    ).fit(X_tr, y_tr)

    probabilidade = modelo.predict_proba(X_te)[:, 1]
    auc = roc_auc_score(y_te, probabilidade)
    ap = average_precision_score(y_te, probabilidade)

    mlflow.log_metric("val_auc", auc)
    mlflow.log_metric("val_average_precision", ap)
    mlflow.log_metric("baseline_auc", BASELINE)
    mlflow.log_metric("baseline_recencia_auc", baseline_recencia)
    mlflow.log_metric("baseline_frequencia_auc", baseline_frequencia)
    mlflow.log_metric("ganho_sobre_baseline", auc - BASELINE)
    mlflow.log_param("data_corte", str(dados["_referencia"].iloc[0]))
    mlflow.log_param("n_features", len(FEATURES))

    # `artifact_path` (não `name`): o serverless do Free Edition traz MLflow
    # 2.x, e o argumento `name` só existe no MLflow 3.
    info = mlflow.sklearn.log_model(
        modelo,
        artifact_path="model",
        input_example=X_tr.head(3),
        registered_model_name=MODELO,     # é aqui que ele entra no Unity Catalog
    )

print(f"AUC do modelo   {auc:.4f}")
print(f"AUC do baseline {BASELINE:.4f}")
print(f"Ganho           {auc - BASELINE:+.4f}")
print()
print(classification_report(y_te, modelo.predict(X_te), target_names=["não comprou", "comprou"]))

# COMMAND ----------
# MAGIC %md
# MAGIC ## 3 · O que o modelo olhou
# MAGIC
# MAGIC `HistGradientBoosting` não expõe `feature_importances_`, então usamos
# MAGIC **importância por permutação**: embaralha uma coluna de cada vez e mede
# MAGIC quanto o AUC piora. É mais lento e mais honesto — mede o que a coluna
# MAGIC contribui de fato, não quantas vezes a árvore a usou.
# MAGIC
# MAGIC Esta é a tabela para mostrar na tela. Se `atraso_relativo` estiver no
# MAGIC topo, a aula toda se justifica sozinha: a coluna que mais pesa não veio
# MAGIC de biblioteca nenhuma, veio de entender como distribuição funciona.

# COMMAND ----------

from sklearn.inspection import permutation_importance

imp = permutation_importance(modelo, X_te, y_te, n_repeats=5, random_state=42, scoring="roc_auc")
ranking = (pd.DataFrame({"feature": FEATURES, "peso": imp.importances_mean})
             .sort_values("peso", ascending=False).reset_index(drop=True))
print(ranking.head(10).to_string(index=False))

# Grava como tabela: assim o ranking fica consultável em SQL, aparece no Genie
# e o notebook de conferência lê sem precisar da API do MLflow.
from pyspark.sql import functions as F

(spark.createDataFrame(ranking.assign(versao=int(info.registered_model_version)))
      .withColumn("_treinado_em", F.current_timestamp())
      .write.mode("overwrite").option("overwriteSchema", "true")
      .saveAsTable(f"{catalog}.gold.modelo_importancia"))

spark.sql(f"""
  COMMENT ON TABLE {catalog}.gold.modelo_importancia IS
  'Importância por permutação de cada feature do modelo de propensão: quanto o AUC piora ao embaralhar a coluna.'
""")

# COMMAND ----------
# MAGIC %md
# MAGIC ## 4 · O alias `@challenger`
# MAGIC
# MAGIC Unity Catalog não tem mais os estágios `Staging`/`Production` do MLflow
# MAGIC antigo. Tem **alias**: um apelido móvel apontando para uma versão.
# MAGIC
# MAGIC A diferença prática: quem consome escreve `models:/…@prod` e nunca
# MAGIC precisa saber o número da versão. Promover e reverter são o mesmo
# MAGIC comando com um número diferente.
# MAGIC
# MAGIC **O treino não promove nada.** Ele apenas apresenta um candidato como
# MAGIC `@challenger`; quem decide é a tarefa `ml_promocao`, comparando com o
# MAGIC que está em produção. Separar as duas coisas é o que impede um retreino
# MAGIC ruim de entrar em produção sozinho às 6h da manhã.
# MAGIC
# MAGIC A única exceção é a primeira vez: sem nenhum `@prod`, não há o que
# MAGIC comparar, e o candidato assume.

# COMMAND ----------

cliente = MlflowClient(registry_uri="databricks-uc")
cliente.set_registered_model_alias(MODELO, "challenger", info.registered_model_version)

try:
    atual_em_prod = cliente.get_model_version_by_alias(MODELO, "prod").version
    print(f"@prod continua na versão {atual_em_prod}; a decisão é da tarefa ml_promocao")
except Exception:
    cliente.set_registered_model_alias(MODELO, "prod", info.registered_model_version)
    print(f"primeira versão do modelo: {info.registered_model_version} assume @prod direto")

cliente.update_registered_model(
    MODELO,
    description=(
        "Propensão de compra nos próximos 30 dias, por cliente. "
        "Treinado sobre gold.features_treino com corte em 2026-08-01. "
        "Consumido em batch pela tarefa ml_score, que grava gold.score_propensao."
    ),
)

print(f"{MODELO} versão {info.registered_model_version} → @challenger")

# COMMAND ----------
# MAGIC %md
# MAGIC ## 5 · O holdout vira tabela
# MAGIC
# MAGIC As previsões dos 704 clientes que o modelo **não viu no treino**, ao
# MAGIC lado do que aconteceu de verdade com eles. É a única base honesta para
# MAGIC responder "o score separa mesmo?".
# MAGIC
# MAGIC **Não dá para usar `gold.score_propensao` para isso**, e o motivo é
# MAGIC sutil o bastante para valer um minuto de aula: aquela tabela pontua a
# MAGIC referência 2026-08-31, e o rótulo que temos é de agosto. Comparar as
# MAGIC duas é comparar uma previsão de setembro com um resultado de agosto —
# MAGIC dois pontos diferentes na linha do tempo. O gráfico sai invertido e a
# MAGIC conclusão sai errada.

# COMMAND ----------

validacao = X_te.copy()
validacao["cliente_id"] = dados.loc[X_te.index, "cliente_id"].values
validacao["comprou_30d"] = y_te.values
validacao["score"] = probabilidade

(spark.createDataFrame(validacao[["cliente_id", "score", "comprou_30d"]]
                       .assign(versao=int(info.registered_model_version)))
      .write.mode("overwrite").option("overwriteSchema", "true")
      .saveAsTable(f"{catalog}.gold.modelo_validacao"))

spark.sql(f"""
  COMMENT ON TABLE {catalog}.gold.modelo_validacao IS
  'Previsões do modelo sobre o conjunto de teste (clientes que ele não viu no treino), ao lado do que aconteceu de fato. Base para medir se o score separa.'
""")

# COMMAND ----------
# MAGIC %md
# MAGIC ## 6 · As métricas viram tabela
# MAGIC
# MAGIC O MLflow guarda tudo, mas quem vai cobrar qualidade do modelo é o teste
# MAGIC em SQL da próxima tarefa — e teste em SQL lê tabela, não API. Uma linha
# MAGIC por treino: é o histórico de qualidade do modelo ao longo do tempo.

# COMMAND ----------

from pyspark.sql import functions as F

metricas = spark.createDataFrame(pd.DataFrame([{
    "modelo": MODELO,
    "versao": int(info.registered_model_version),
    "run_id": run.info.run_id,
    "data_corte": str(dados["_referencia"].iloc[0]),
    "linhas_treino": int(len(X_tr)),
    "linhas_teste": int(len(X_te)),
    "taxa_positiva": float(y.mean()),
    "auc": float(auc),
    "average_precision": float(ap),
    "baseline_auc": float(BASELINE),
    "baseline_recencia_auc": float(baseline_recencia),
    "baseline_frequencia_auc": float(baseline_frequencia),
    "ganho_sobre_baseline": float(auc - BASELINE),
    "feature_mais_importante": ranking.iloc[0]["feature"],
}])).withColumn("_treinado_em", F.current_timestamp())

(metricas.write.mode("append").option("mergeSchema", "true")
         .saveAsTable(f"{catalog}.gold.modelo_metricas"))

spark.sql(f"""
  COMMENT ON TABLE {catalog}.gold.modelo_metricas IS
  'Uma linha por treino do modelo de propensão. Histórico de qualidade: AUC, baseline e ganho.'
""")

dbutils.notebook.exit(json.dumps({
    "versao": info.registered_model_version,
    "auc": round(float(auc), 4),
    "baseline": round(float(BASELINE), 4),
    "ganho": round(float(auc - BASELINE), 4),
}))
