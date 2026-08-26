# Databricks notebook source
# MAGIC %md
# MAGIC # ML · features do cliente
# MAGIC
# MAGIC A parte do projeto que mais vale dinheiro, e a que menos aparece em
# MAGIC tutorial. O modelo da próxima tarefa é dez linhas de scikit-learn; o que
# MAGIC decide se ele presta ou não é o que está escrito **aqui**.
# MAGIC
# MAGIC ## A regra que organiza o arquivo inteiro: a data de referência
# MAGIC
# MAGIC Toda feature aqui é calculada com dado **anterior** a uma data de corte.
# MAGIC Nenhuma exceção. É isso que separa um modelo de um autoengano:
# MAGIC
# MAGIC - se a feature enxerga o que aconteceu **depois** do rótulo, o AUC vem
# MAGIC   0,99 e você acha que é gênio;
# MAGIC - em produção o modelo despenca, porque no dia da previsão o futuro
# MAGIC   ainda não existe.
# MAGIC
# MAGIC Isso se chama **vazamento de dado** (*data leakage*), e é o erro nº 1 de
# MAGIC quem está começando. A defesa não é lembrar de tomar cuidado — é ter uma
# MAGIC função só, com a data como parâmetro, e usar ela nos dois lugares.
# MAGIC
# MAGIC ## Por que este notebook grava DUAS tabelas
# MAGIC
# MAGIC A mesma função `montar_features()` roda duas vezes, com datas diferentes:
# MAGIC
# MAGIC | Tabela | Referência | Para quê |
# MAGIC |---|---|---|
# MAGIC | `gold.features_treino` | 2026-08-01 | tem rótulo: o cliente comprou em agosto? |
# MAGIC | `gold.features_cliente` | 2026-08-31 | não tem rótulo: é o que o modelo vai pontuar |
# MAGIC
# MAGIC Uma função, dois usos. Se a conta de `atraso_relativo` mudar amanhã, ela
# MAGIC muda nos dois ao mesmo tempo — e é impossível o treino e o score
# MAGIC discordarem. Esse desencontro tem nome na literatura
# MAGIC (*training/serving skew*) e é o que o Feature Store resolve com
# MAGIC infraestrutura. Aqui ele está resolvido com uma função.

# COMMAND ----------

dbutils.widgets.text("catalog", "lakehouse_rotaperfume")
catalog = dbutils.widgets.get("catalog")

# O "hoje" do dataset. A base vai de 2024-09-01 a 2026-08-31, e a seed é fixa:
# a data NÃO pode ser current_date(), senão o número de cada aluno é diferente
# e ninguém consegue conferir com o da tela.
FIM_DA_BASE = "2026-08-31"

# O corte de treino. Features até aqui, rótulo nos 30 dias seguintes.
CORTE_TREINO = "2026-08-01"
JANELA_ROTULO_DIAS = 30

# COMMAND ----------

from pyspark.sql import functions as F, Window


def montar_features(referencia: str):
    """Uma linha por cliente, com tudo que se sabia dele ATÉ `referencia`.

    O filtro `data < referencia` aparece logo na primeira linha de cada fonte,
    de propósito: é mais fácil revisar um filtro que está no topo do que
    procurar por ele no meio de trinta agregações.
    """
    fato = spark.table(f"{catalog}.gold.fato_vendas").filter(F.col("data_pedido") < referencia)
    visitas = spark.table(f"{catalog}.silver.visitas").filter(F.col("data_visita") < referencia)
    oport = spark.table(f"{catalog}.silver.oportunidades").filter(F.col("data_abertura") < referencia)

    # ── RFM: recência, frequência, valor ──────────────────────────────────
    # O feijão com arroz de análise de cliente, e ainda hoje o que mais explica.
    #
    # CAST para DOUBLE não é frescura: a gold usa DECIMAL(18,2), e DECIMAL vira
    # `Decimal` no pandas. Na hora de registrar o modelo, o MLflow serializa o
    # exemplo de entrada em JSON e morre com
    # `Object of type Decimal is not JSON serializable`.
    rfm = (
        fato.groupBy("cliente_id")
        .agg(
            F.datediff(F.lit(referencia), F.max("data_pedido")).alias("recencia_dias"),
            F.countDistinct("pedido_id").alias("frequencia_pedidos"),
            F.sum("receita").cast("double").alias("valor_total"),
            F.sum("margem").cast("double").alias("margem_total"),
            F.countDistinct("sku").alias("skus_distintos"),
            F.countDistinct("categoria").alias("categorias_distintas"),
            F.countDistinct("marca").alias("marcas_distintas"),
            F.countDistinct("canal").alias("canais_distintos"),
            F.sum(F.when(F.col("devolucao"), 1).otherwise(0)).alias("devolucoes"),
            F.min("data_pedido").alias("primeira_compra"),
        )
        .withColumn("meses_de_casa",
                    F.months_between(F.lit(referencia), F.col("primeira_compra")).cast("double"))
        .withColumn("pedidos_por_mes",
                    F.col("frequencia_pedidos") / F.greatest(F.col("meses_de_casa"), F.lit(1.0)))
        .withColumn("ticket_medio",
                    F.col("valor_total") / F.greatest(F.col("frequencia_pedidos"), F.lit(1)))
        .drop("primeira_compra")
    )

    # ── ritmo de compra: de quanto em quanto tempo esse cliente volta ─────
    janela = Window.partitionBy("cliente_id").orderBy("data_pedido")
    ritmo = (
        fato.select("cliente_id", "data_pedido").distinct()
        .withColumn("pedido_anterior", F.lag("data_pedido").over(janela))
        .withColumn("intervalo", F.datediff("data_pedido", "pedido_anterior"))
        .groupBy("cliente_id")
        .agg(
            F.avg("intervalo").cast("double").alias("intervalo_medio_dias"),
            F.stddev("intervalo").cast("double").alias("intervalo_desvio"),
        )
    )

    # ── tendência: quanto da receita do cliente é recente ─────────────────
    # Dois clientes com o mesmo total: um comprou tudo no ano passado, o outro
    # nos últimos três meses. O total não distingue os dois. Esta coluna sim.
    tendencia = (
        fato.filter(F.col("data_pedido") >= F.date_sub(F.lit(referencia).cast("date"), 90))
        .groupBy("cliente_id")
        .agg(F.sum("receita").cast("double").alias("receita_90d"))
    )

    # ── sinais do CRM: o que o time comercial fez, não o que o cliente comprou ─
    # Visita sem pedido é o dado mais subestimado de uma operação B2B: ele diz
    # que houve esforço e não houve resultado — e isso prevê.
    crm = (
        oport.groupBy("cliente_id")
        .agg(F.count("*").alias("oportunidades"),
             F.sum(F.when(F.col("ganha"), 1).otherwise(0)).alias("oportunidades_ganhas"))
    )
    campo = (
        visitas.groupBy("cliente_id")
        .agg(F.count("*").alias("visitas"),
             F.sum(F.when(F.col("gerou_pedido"), 1).otherwise(0)).alias("visitas_com_pedido"))
    )

    return (
        rfm.join(ritmo, "cliente_id", "left")
        .join(tendencia, "cliente_id", "left")
        .join(crm, "cliente_id", "left")
        .join(campo, "cliente_id", "left")
        # Cliente com um pedido só não tem intervalo entre pedidos. 999 diz
        # "nunca voltou"; 0 diria "voltou no mesmo dia", que é o oposto.
        .fillna({"intervalo_medio_dias": 999.0, "intervalo_desvio": 0.0, "receita_90d": 0.0,
                 "oportunidades": 0, "oportunidades_ganhas": 0, "visitas": 0, "visitas_com_pedido": 0})
        # ── A FEATURE QUE NÃO VEM DE BIBLIOTECA NENHUMA ───────────────────
        # Recência sozinha não quer dizer nada. "Sumiu há 20 dias" é urgente
        # para quem compra toda semana e é rotina para quem compra por
        # trimestre. Dividir uma pela outra é conhecimento de negócio virando
        # coluna — e é a coluna que o modelo mais usa.
        .withColumn("atraso_relativo",
                    F.col("recencia_dias") / F.greatest(F.col("intervalo_medio_dias"), F.lit(1.0)))
        .withColumn("taxa_conversao_visita",
                    F.col("visitas_com_pedido") / F.greatest(F.col("visitas"), F.lit(1)))
        .withColumn("peso_90d",
                    F.col("receita_90d") / F.greatest(F.col("valor_total"), F.lit(1.0)))
    )

# COMMAND ----------
# MAGIC %md
# MAGIC ## 1 · As features de treino, com o rótulo colado
# MAGIC
# MAGIC O rótulo responde a pergunta de negócio da noite em uma linha:
# MAGIC **este cliente vai comprar nos próximos 30 dias?**
# MAGIC
# MAGIC Repare na assimetria: as features param em 01/08 e o rótulo começa em
# MAGIC 01/08. Elas não se tocam. É a coisa mais importante deste arquivo.

# COMMAND ----------

fim_janela = F.date_add(F.lit(CORTE_TREINO).cast("date"), JANELA_ROTULO_DIAS)

rotulo = (
    spark.table(f"{catalog}.gold.fato_vendas")
    .filter((F.col("data_pedido") >= CORTE_TREINO) & (F.col("data_pedido") < fim_janela))
    .select("cliente_id").distinct()
    .withColumn("comprou_30d", F.lit(1))
)

treino = (
    montar_features(CORTE_TREINO)
    .join(rotulo, "cliente_id", "left")
    .fillna({"comprou_30d": 0})
    .withColumn("_referencia", F.lit(CORTE_TREINO).cast("date"))
)

(treino.write.mode("overwrite").option("overwriteSchema", "true")
       .saveAsTable(f"{catalog}.gold.features_treino"))

# COMMAND ----------
# MAGIC %md
# MAGIC ## 2 · As features de score, sem rótulo
# MAGIC
# MAGIC Mesma função, data diferente. Aqui não há rótulo — e não há porque o
# MAGIC futuro que queremos prever (setembro) simplesmente não existe na base.
# MAGIC É essa a situação real de todo modelo em produção.

# COMMAND ----------

atual = montar_features(FIM_DA_BASE).withColumn("_referencia", F.lit(FIM_DA_BASE).cast("date"))

(atual.write.mode("overwrite").option("overwriteSchema", "true")
      .saveAsTable(f"{catalog}.gold.features_cliente"))

# COMMAND ----------
# MAGIC %md
# MAGIC ## 3 · O metadado, igual ao de qualquer tabela da gold
# MAGIC
# MAGIC Tabela de feature não é rascunho de cientista de dados: ela é gold, e
# MAGIC obedece à mesma auditoria de metadado do prompt 6 de ontem — que quebra
# MAGIC o job se encontrar coluna sem `COMMENT`.

# COMMAND ----------

DESCRICOES = {
    "cliente_id": "Identificador do cliente. Liga com gold.dim_cliente.",
    "recencia_dias": "Dias entre o último pedido do cliente e a data de referência.",
    "frequencia_pedidos": "Pedidos distintos que o cliente fez até a data de referência.",
    "valor_total": "Receita acumulada do cliente até a data de referência, com devolução descontada.",
    "margem_total": "Margem acumulada do cliente até a data de referência.",
    "skus_distintos": "Quantidade de produtos diferentes que o cliente já comprou.",
    "categorias_distintas": "Quantidade de categorias diferentes que o cliente já comprou.",
    "marcas_distintas": "Quantidade de marcas diferentes que o cliente já comprou.",
    "canais_distintos": "Em quantos canais diferentes o cliente já fez pedido.",
    "devolucoes": "Itens devolvidos pelo cliente no histórico.",
    "meses_de_casa": "Meses entre a primeira compra do cliente e a data de referência.",
    "pedidos_por_mes": "Frequência de pedidos dividida pelos meses de casa.",
    "ticket_medio": "Receita acumulada dividida pelo número de pedidos.",
    "intervalo_medio_dias": "Média de dias entre dois pedidos consecutivos. 999 quando o cliente só tem um pedido.",
    "intervalo_desvio": "Desvio padrão do intervalo entre pedidos. Alto significa compra irregular.",
    "receita_90d": "Receita do cliente nos 90 dias anteriores à data de referência.",
    "oportunidades": "Oportunidades abertas para o cliente no CRM.",
    "oportunidades_ganhas": "Oportunidades que fecharam como ganhas.",
    "visitas": "Visitas que o time comercial fez ao cliente.",
    "visitas_com_pedido": "Visitas que terminaram em pedido.",
    "atraso_relativo": "Recência dividida pelo intervalo médio do próprio cliente. Acima de 1 o cliente está atrasado PARA O PADRÃO DELE. É a feature que o modelo mais usa.",
    "taxa_conversao_visita": "Visitas com pedido sobre o total de visitas, de 0 a 1.",
    "peso_90d": "Fatia da receita do cliente que veio dos últimos 90 dias, de 0 a 1. Separa quem comprava antes de quem compra agora.",
    "comprou_30d": "RÓTULO: 1 quando o cliente fez pedido nos 30 dias seguintes à data de referência. Só existe em features_treino.",
    "_referencia": "Data de corte usada para calcular todas as features desta linha. Nenhuma coluna enxerga dado posterior a ela.",
}

for tabela, comentario in [
    ("features_treino", "Features do cliente na data de corte de treino, com o rótulo comprou_30d colado. Uma linha por cliente."),
    ("features_cliente", "Features do cliente na data mais recente da base. Uma linha por cliente. É a tabela que o modelo pontua."),
]:
    spark.sql(f"COMMENT ON TABLE {catalog}.gold.{tabela} IS '{comentario}'")
    colunas = {c.name for c in spark.table(f"{catalog}.gold.{tabela}").schema.fields}
    for coluna, texto in DESCRICOES.items():
        if coluna in colunas:
            spark.sql(f"ALTER TABLE {catalog}.gold.{tabela} ALTER COLUMN {coluna} COMMENT '{texto}'")

# COMMAND ----------

from pyspark.sql import functions as F

resumo = spark.table(f"{catalog}.gold.features_treino")
total = resumo.count()
positivos = resumo.agg(F.sum("comprou_30d")).first()[0]

print(f"features_treino   {total:>6} clientes · {positivos} compraram nos 30 dias seguintes "
      f"({positivos / total:.1%})")
print(f"features_cliente  {spark.table(f'{catalog}.gold.features_cliente').count():>6} clientes na referência {FIM_DA_BASE}")

# Um rótulo muito desequilibrado torna o modelo inútil na prática: com 3% de
# positivos, chutar "ninguém compra" acerta 97% e não serve para nada. Se isso
# acontecer, a janela do rótulo é o que precisa mudar — não o modelo.
if not 0.05 < positivos / total < 0.95:
    raise ValueError(
        f"Rótulo desequilibrado: {positivos / total:.1%} de positivos. "
        f"Ajuste JANELA_ROTULO_DIAS ou CORTE_TREINO."
    )
