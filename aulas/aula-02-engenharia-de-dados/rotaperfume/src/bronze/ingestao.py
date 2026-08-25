# Databricks notebook source
# MAGIC %md
# MAGIC # Bronze · ingestão
# MAGIC
# MAGIC Dez CSVs viram dez tabelas Delta. **Nenhuma limpeza acontece aqui.**
# MAGIC
# MAGIC A regra da bronze é uma só: preservar o dado como veio. Se o Spark
# MAGIC adivinhasse o tipo, ele transformaria `15/10/2025` em nulo e apagaria os
# MAGIC zeros à esquerda de 309 CNPJs — a sujeira sumiria antes de alguém ver que
# MAGIC ela existia, e ninguém saberia se o erro veio da origem ou da limpeza.
# MAGIC
# MAGIC Por isso **tudo entra como texto**, de propósito. Converter é trabalho da
# MAGIC silver, feito sabendo o que se faz.
# MAGIC
# MAGIC As duas únicas colunas que a bronze acrescenta respondem as duas primeiras
# MAGIC perguntas de qualquer investigação: `_ingerido_em` (quando isso entrou?) e
# MAGIC `_arquivo_origem` (de qual arquivo veio?).

# COMMAND ----------

dbutils.widgets.text("catalog", "lakehouse_rotaperfume")
catalog = dbutils.widgets.get("catalog")

RAIZ = f"/Volumes/{catalog}/bronze/raw"

# Uma função e uma lista. Se amanhã o ERP mandar a décima primeira tabela,
# é uma linha aqui — não um bloco copiado e colado.
TABELAS = [
    ("erp", "produtos",      "Catálogo de SKUs do ERP: marca, categoria, nota olfativa, custo e preço."),
    ("erp", "pedidos",       "Cabeçalho do pedido no ERP: cliente, vendedor, canal, status e valor."),
    ("erp", "itens_pedido",  "Item de pedido no ERP: SKU, quantidade, preço praticado e desconto."),
    ("erp", "pagamentos",    "Financeiro do ERP: forma, parcelas, taxa, vencimento e baixa."),
    ("erp", "estoque",       "Snapshot semanal de saldo por SKU no ERP, com marcação de ruptura."),
    ("crm", "clientes",      "Cadastro de clientes do CRM: CNPJ, razão social, segmento e cidade."),
    ("crm", "vendedores",    "Equipe comercial no CRM: região, admissão, desligamento e meta."),
    ("crm", "carteira",      "Vínculo cliente × vendedor no CRM, com vigência."),
    ("crm", "oportunidades", "Funil comercial do CRM: origem, etapa, valor estimado e motivo de perda."),
    ("crm", "visitas",       "Visitas registradas no CRM: data, resultado e duração."),
]

# COMMAND ----------

from pyspark.sql import functions as F


def ingerir(sistema: str, tabela: str, comentario: str) -> int:
    """Lê um CSV do Volume e grava a tabela bronze correspondente.

    header=True     → a primeira linha é o nome das colunas
    inferSchema=False → TUDO vira string. É a decisão central da camada.
    """
    origem = f"{RAIZ}/{sistema}/{tabela}.csv"
    destino = f"{catalog}.bronze.{tabela}"

    df = (
        spark.read
        .option("header", True)
        .option("inferSchema", False)   # a bronze não adivinha tipo
        .csv(origem)
        # _metadata é uma coluna escondida que o Spark oferece em toda leitura
        # de arquivo. De graça, e vale mais que qualquer log.
        .withColumn("_arquivo_origem", F.col("_metadata.file_path"))
        .withColumn("_ingerido_em", F.current_timestamp())
    )

    df.write.mode("overwrite").option("overwriteSchema", "true").saveAsTable(destino)
    spark.sql(f"COMMENT ON TABLE {destino} IS '{comentario} Ingerida como texto, sem limpeza.'")
    return spark.table(destino).count()


contagens = {tabela: ingerir(sistema, tabela, c) for sistema, tabela, c in TABELAS}

# COMMAND ----------

# A conferência que fecha o ciclo com o prompt anterior: o que a tabela tem
# precisa ser exatamente o que o arquivo trouxe. Se divergir, algo se perdeu
# na leitura — e é melhor descobrir agora do que no dashboard.
esperado = {
    r.arquivo.replace(".csv", ""): r.linhas
    for r in spark.table(f"{catalog}.bronze._raw_arquivos").collect()
}

print(f"{'tabela':<16} {'no arquivo':>12} {'na bronze':>12}   ")
print("-" * 48)
divergencias = []
for _, tabela, _ in TABELAS:
    a, b = esperado.get(tabela), contagens[tabela]
    marca = "ok" if a == b else "DIVERGIU"
    if a != b:
        divergencias.append(f"{tabela}: arquivo {a}, tabela {b}")
    print(f"{tabela:<16} {a:>12,} {b:>12,}   {marca}")
print("-" * 48)
print(f"{'TOTAL':<16} {sum(esperado.values()):>12,} {sum(contagens.values()):>12,}")

if divergencias:
    raise Exception("Contagem não bate entre o arquivo e a tabela: " + "; ".join(divergencias))
