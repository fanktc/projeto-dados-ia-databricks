"""Ingestão bronze: do CSV no volume para tabela Delta.

A bronze preserva o dado como veio. Nada de limpeza aqui — se der problema
depois, a gente precisa poder voltar na origem e comparar.

A regra que sustenta tudo isso é `inferSchema=false`: toda coluna entra como
texto. Se o Spark adivinhasse o tipo, erraria as datas que vêm em dois
formatos e o CNPJ perderia os zeros à esquerda. A sujeira sumiria antes de
alguém ver que ela existe.
"""

from pyspark.sql import DataFrame, SparkSession, functions as F

# Cada tabela e a subpasta de onde ela vem. A ordem é a de leitura.
TABELAS: dict[str, str] = {
    "produtos": "erp",
    "pedidos": "erp",
    "itens_pedido": "erp",
    "pagamentos": "erp",
    "estoque": "erp",
    "clientes": "crm",
    "vendedores": "crm",
    "carteira": "crm",
    "oportunidades": "crm",
    "visitas": "crm",
}

# Quantas linhas cada tabela deve ter. O gerador usa seed fixa, então esses
# números são determinísticos: se um deles mudar, ou a origem mudou ou a
# ingestão comeu linha.
LINHAS_ESPERADAS: dict[str, int] = {
    "produtos": 292,
    "pedidos": 28_729,
    "itens_pedido": 197_724,
    "pagamentos": 27_772,
    "estoque": 8_400,
    "clientes": 3_040,
    "vendedores": 42,
    "carteira": 3_637,
    "oportunidades": 5_979,
    "visitas": 37_936,
}


def caminho_volume(catalog: str, schema: str) -> str:
    return f"/Volumes/{catalog}/{schema}/raw"


def ler_csv(spark: SparkSession, catalog: str, schema: str, tabela: str) -> DataFrame:
    """Lê um CSV do volume sem transformar nada."""
    origem = f"{caminho_volume(catalog, schema)}/{TABELAS[tabela]}/{tabela}.csv"
    return (
        spark.read.option("header", "true")
        .option("inferSchema", "false")  # tudo string: preserva o original
        .csv(origem)
        .withColumn("_ingerido_em", F.current_timestamp())
        .withColumn("_arquivo_origem", F.col("_metadata.file_path"))
    )


def ingerir(spark: SparkSession, catalog: str, schema: str, tabela: str) -> int:
    """Grava uma tabela bronze e devolve a contagem de linhas."""
    df = ler_csv(spark, catalog, schema, tabela)
    destino = f"`{catalog}`.`{schema}`.`{tabela}`"
    df.write.format("delta").mode("overwrite").option(
        "overwriteSchema", "true"
    ).saveAsTable(destino)
    return spark.table(destino).count()


def ingerir_todas(spark: SparkSession, catalog: str, schema: str) -> dict[str, int]:
    """Ingere as 10 tabelas e devolve a contagem de cada uma."""
    contagens = {}
    for tabela in TABELAS:
        n = ingerir(spark, catalog, schema, tabela)
        esperado = LINHAS_ESPERADAS[tabela]
        marca = "ok" if n == esperado else f"ATENÇÃO: esperava {esperado:,}"
        print(f"  {catalog}.{schema}.{tabela:<14} {n:>9,} linhas  {marca}")
        contagens[tabela] = n
    return contagens
