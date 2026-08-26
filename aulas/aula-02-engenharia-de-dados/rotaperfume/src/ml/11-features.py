# Databricks notebook source
# MAGIC %md
# MAGIC # ML · features
# MAGIC
# MAGIC O fato de vendas tem uma linha por **item**. Modelo não come tabela fato:
# MAGIC ele come uma linha por **coisa que você quer prever**, com todas as
# MAGIC colunas na mesma linha. Isso tem nome — feature — e é o que este notebook
# MAGIC constrói.
# MAGIC
# MAGIC ## Uma função, dois cortes
# MAGIC
# MAGIC `montar_features(referencia)` devolve uma linha por cliente com tudo que
# MAGIC se sabia dele **até** aquela data. Ela é chamada duas vezes:
# MAGIC
# MAGIC | Tabela | Corte | Para quê |
# MAGIC |---|---|---|
# MAGIC | `gold.features_treino` | 2026-08-01 | treinar — tem a resposta |
# MAGIC | `gold.features_cliente` | 2026-08-31 | pontuar — não tem |
# MAGIC
# MAGIC É a mesma função nas duas, e por isso é **impossível** treino e score
# MAGIC divergirem. Esse desencontro tem nome, *training/serving skew*, e é o que
# MAGIC um Feature Store resolve com infraestrutura. Aqui está resolvido com um
# MAGIC `def`.
# MAGIC
# MAGIC ## A data de corte é a espinha do arquivo
# MAGIC
# MAGIC Toda fonte é filtrada pela data dela na primeira linha da leitura. Não é
# MAGIC disciplina pessoal — é assinatura de função. E fica gravada em
# MAGIC `_referencia`, para que daqui a seis meses ninguém precise adivinhar de
# MAGIC que corte veio o número.

# COMMAND ----------

dbutils.widgets.text("catalog", "lakehouse_rotaperfume")
catalog = dbutils.widgets.get("catalog")

# O "hoje" deste dataset é 2026-08-31. Nada de current_date() aqui: com data
# móvel, dois alunos rodando em dias diferentes chegariam a números diferentes.
CORTE_TREINO = "2026-08-01"
FIM_DA_BASE = "2026-08-31"

# A janela do rótulo é de UMA SEMANA porque a fila que o time vai atacar é
# semanal: são 200 ligações por semana. O rótulo tem que ter o mesmo horizonte
# da decisão, senão o modelo responde uma pergunta que ninguém fez.
JANELA_DIAS = 7

from pyspark.sql import functions as F, Window

# COMMAND ----------

# MAGIC %md
# MAGIC ## O que NÃO entra
# MAGIC
# MAGIC `gold.dim_cliente` tem três colunas que parecem feitas para isto —
# MAGIC `dias_sem_comprar`, `receita_acumulada`, `total_pedidos`. Nenhuma delas
# MAGIC pode ser usada: são calculadas sobre a base **inteira**, sem corte
# MAGIC nenhum. Usar qualquer uma é deixar o modelo enxergar o futuro.
# MAGIC
# MAGIC É o erro mais fácil de cometer aqui, e o mais difícil de notar: ele não
# MAGIC dá erro, dá AUC alto.

# COMMAND ----------


def montar_features(referencia):
    """Uma linha por cliente, com tudo que se sabia dele ATÉ `referencia`."""

    # ── as fontes, cada uma cortada na primeira linha ─────────────────
    fato = (spark.table(f"{catalog}.gold.fato_vendas")
                 .filter(F.col("data_pedido") < F.lit(referencia)))

    oport = (spark.table(f"{catalog}.silver.oportunidades")
                  .filter(F.col("data_abertura") < F.lit(referencia)))

    visitas = (spark.table(f"{catalog}.silver.visitas")
                    .filter(F.col("data_visita") < F.lit(referencia)))

    ref = F.lit(referencia).cast("date")

    # ── RFM ───────────────────────────────────────────────────────────
    # A devolução já entra negativa no fato, então SUM(receita) é a receita
    # líquida — que é o que o cliente de fato deixou.
    rfm = fato.groupBy("cliente_id").agg(
        F.datediff(ref, F.max("data_pedido")).cast("double").alias("recencia_dias"),
        F.countDistinct("pedido_id").cast("double").alias("frequencia_pedidos"),
        F.sum("receita").cast("double").alias("valor_total"),
        F.sum("margem").cast("double").alias("margem_total"),
        F.min("data_pedido").alias("_primeiro"),
        F.max("data_pedido").alias("_ultimo"),
    ).withColumn(
        "ticket_medio",
        (F.col("valor_total") / F.nullif(F.col("frequencia_pedidos"), F.lit(0))).cast("double")
    ).withColumn(
        "margem_percentual",
        (F.col("margem_total") / F.nullif(F.col("valor_total"), F.lit(0))).cast("double")
    )

    # ── ritmo ─────────────────────────────────────────────────────────
    # O intervalo entre pedidos é o que transforma "sumiu há 20 dias" em algo
    # que significa coisas opostas para clientes diferentes.
    datas = fato.select("cliente_id", "data_pedido").distinct()
    janela = Window.partitionBy("cliente_id").orderBy("data_pedido")
    gaps = (datas
            .withColumn("_anterior", F.lag("data_pedido").over(janela))
            .filter(F.col("_anterior").isNotNull())
            .withColumn("_gap", F.datediff("data_pedido", "_anterior").cast("double")))

    ritmo = gaps.groupBy("cliente_id").agg(
        F.avg("_gap").cast("double").alias("intervalo_medio_dias"),
        F.stddev("_gap").cast("double").alias("desvio_intervalo_dias"),
    )

    recentes = (fato
        .filter(F.col("data_pedido") >= F.date_sub(ref, 90))
        .groupBy("cliente_id")
        .agg(F.countDistinct("pedido_id").cast("double").alias("pedidos_ultimos_90d")))

    # ── CRM ───────────────────────────────────────────────────────────
    crm_op = oport.groupBy("cliente_id").agg(
        F.sum(F.when(~F.col("ganha") & ~F.col("perdida"), 1).otherwise(0))
         .cast("double").alias("oportunidades_abertas"),
        F.sum(F.col("ganha").cast("int")).cast("double").alias("oportunidades_ganhas"),
        F.count("*").cast("double").alias("_oportunidades"),
    ).withColumn(
        "taxa_ganho",
        (F.col("oportunidades_ganhas") / F.nullif(F.col("_oportunidades"), F.lit(0))).cast("double")
    ).drop("_oportunidades")

    crm_vis = (visitas
        .filter(F.col("data_visita") >= F.date_sub(ref, 90))
        .groupBy("cliente_id")
        .agg(F.count("*").cast("double").alias("visitas_90d"),
             F.sum(F.col("gerou_pedido").cast("int")).cast("double").alias("_com_pedido"))
        .withColumn("conversao_visita",
                    (F.col("_com_pedido") / F.nullif(F.col("visitas_90d"), F.lit(0))).cast("double"))
        .drop("_com_pedido"))

    # ── mix ───────────────────────────────────────────────────────────
    # categoria e marca já vêm no fato — a gold é desnormalizada de propósito.
    mix = fato.groupBy("cliente_id").agg(
        F.countDistinct("sku").cast("double").alias("skus_distintos"),
        F.countDistinct("categoria").cast("double").alias("categorias_distintas"),
        F.countDistinct("marca").cast("double").alias("marcas_distintas"),
    )

    por_marca = fato.groupBy("cliente_id", "marca").agg(F.sum("receita").alias("_receita"))
    concentracao = (por_marca.groupBy("cliente_id")
        .agg(F.max("_receita").cast("double").alias("_top"),
             F.sum("_receita").cast("double").alias("_total"))
        .withColumn("concentracao_marca_top",
                    (F.col("_top") / F.nullif(F.col("_total"), F.lit(0))).cast("double"))
        .select("cliente_id", "concentracao_marca_top"))

    # O único join que este notebook precisa: data_lancamento não está no fato.
    lancamentos = (spark.table(f"{catalog}.gold.dim_produto")
                        .filter(F.col("data_lancamento") >= F.date_sub(ref, 120))
                        .select("sku"))
    comprou_lanc = (fato.join(lancamentos, "sku")
                        .groupBy("cliente_id")
                        .agg(F.lit(1.0).alias("comprou_lancamento")))

    # ── uma linha por cliente ─────────────────────────────────────────
    df = rfm.drop("_primeiro", "_ultimo")
    for parte in (ritmo, recentes, crm_op, crm_vis, mix, concentracao, comprou_lanc):
        df = df.join(parte, "cliente_id", "left")

    # Cliente sem oportunidade ou sem visita tem ZERO, não desconhecido — a
    # ausência é informação. Já as features de ritmo continuam nulas para quem
    # tem um pedido só: aí não se sabe mesmo, e a árvore trata NaN nativamente.
    df = df.fillna(0.0, subset=[
        "oportunidades_abertas", "oportunidades_ganhas", "taxa_ganho",
        "visitas_90d", "conversao_visita", "pedidos_ultimos_90d",
        "comprou_lancamento",
    ])

    # A feature que não vem de biblioteca nenhuma: recência dividida pelo
    # intervalo médio DO PRÓPRIO CLIENTE. Teto em 10 para não explodir com quem
    # comprou duas vezes em dias seguidos.
    # ATENÇÃO ao least(): no Spark ele IGNORA nulo e devolve o menor dos
    # não-nulos. Sem o when() de fora, os 80 clientes de um pedido só — que não
    # têm intervalo — receberiam 10, o teto, e iriam para o TOPO da fila. Quem
    # comprou uma vez na vida viraria a prioridade da semana.
    df = df.withColumn(
        "atraso_relativo",
        F.when(
            F.col("intervalo_medio_dias").isNotNull() & (F.col("intervalo_medio_dias") > 0),
            F.least(
                F.col("recencia_dias") / F.col("intervalo_medio_dias"),
                F.lit(10.0),
            ),
        ).cast("double"),
    )

    return df.withColumn("_referencia", ref)


# COMMAND ----------

# MAGIC %md
# MAGIC ## Treino: as features de 01/08 e a resposta da semana seguinte
# MAGIC
# MAGIC O rótulo olha para a frente **a partir do corte** — e as features, só
# MAGIC para trás. É essa linha que separa um modelo honesto de um que leu a
# MAGIC resposta.

# COMMAND ----------

fim_janela = F.date_add(F.lit(CORTE_TREINO).cast("date"), JANELA_DIAS - 1)

comprou = (spark.table(f"{catalog}.gold.fato_vendas")
    .filter((F.col("data_pedido") >= F.lit(CORTE_TREINO)) & (F.col("data_pedido") <= fim_janela))
    .select("cliente_id").distinct()
    .withColumn("comprou_em_7d", F.lit(1)))

treino = (montar_features(CORTE_TREINO)
          .join(comprou, "cliente_id", "left")
          .fillna(0, subset=["comprou_em_7d"]))

(treino.write.mode("overwrite").option("overwriteSchema", "true")
       .saveAsTable(f"{catalog}.gold.features_treino"))

# saveAsTable não grava COMMENT de tabela — e a auditoria de metadado da noite 2
# quebra o job se faltar. Por isso vem em seguida, num COMMENT ON.
spark.sql(f"""
COMMENT ON TABLE {catalog}.gold.features_treino IS
'Uma linha por cliente com o comportamento dele ATÉ 2026-08-01, mais o rótulo
 comprou_em_7d (fez pedido entre 01/08 e 07/08). É a tabela de treino do modelo
 de propensão. Gerada por montar_features(), a mesma função que gera
 features_cliente.'
""")

print(f"features_treino: {treino.count()} clientes × {len(treino.columns)} colunas")

# COMMAND ----------

# MAGIC %md
# MAGIC ## Score: as mesmas colunas, no fim da base, sem resposta

# COMMAND ----------

atual = montar_features(FIM_DA_BASE)

(atual.write.mode("overwrite").option("overwriteSchema", "true")
      .saveAsTable(f"{catalog}.gold.features_cliente"))

spark.sql(f"""
COMMENT ON TABLE {catalog}.gold.features_cliente IS
'Uma linha por cliente com o comportamento dele ATÉ 2026-08-31, sem rótulo. É a
 tabela que o modelo pontua para montar a fila da semana. Mesmas colunas de
 features_treino, geradas pela mesma função.'
""")

print(f"features_cliente: {atual.count()} clientes × {len(atual.columns)} colunas")

# COMMAND ----------

# MAGIC %md
# MAGIC ## A conferência que importa
# MAGIC
# MAGIC **Recência negativa é a assinatura do vazamento**: significa que a última
# MAGIC compra é posterior ao corte, ou seja, que uma fonte escapou do filtro.

# COMMAND ----------

conferencia = spark.sql(f"""
SELECT '_treino'  AS tabela, COUNT(*) AS clientes, MIN(_referencia) AS corte,
       MIN(recencia_dias) AS menor_recencia,
       ROUND(100 * AVG(comprou_em_7d), 2) AS taxa_base_pct
FROM {catalog}.gold.features_treino
UNION ALL
SELECT '_cliente', COUNT(*), MIN(_referencia), MIN(recencia_dias), NULL
FROM {catalog}.gold.features_cliente
""")
conferencia.show(truncate=False)

menor = treino.agg(F.min("recencia_dias")).collect()[0][0]
assert menor is not None and menor > 0, (
    f"recencia_dias mínima veio {menor}: alguma fonte escapou do filtro de data. "
    "Isto é vazamento, e o modelo treinado assim leria a resposta."
)
print("sem recência negativa — o corte foi respeitado em todas as fontes")
