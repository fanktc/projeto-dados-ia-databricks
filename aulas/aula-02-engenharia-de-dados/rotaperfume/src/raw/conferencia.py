# Databricks notebook source
# MAGIC %md
# MAGIC # Raw · conferência de chegada
# MAGIC
# MAGIC A tarefa mais chata do pipeline, e a que mais salva emprego.
# MAGIC
# MAGIC Arquivo que não chega **não dá erro**. Ele dá número menor — e o dashboard
# MAGIC mostra metade da receita com cara de número certo. Por isso a primeira
# MAGIC coisa que o pipeline faz é conferir se os dez arquivos chegaram, se têm
# MAGIC tamanho e quantas linhas cada um trouxe.
# MAGIC
# MAGIC Nada aqui lê conteúdo de coluna. Isso é trabalho da bronze.

# COMMAND ----------

dbutils.widgets.text("catalog", "lakehouse_rotaperfume")
catalog = dbutils.widgets.get("catalog")

RAIZ = f"/Volumes/{catalog}/bronze/raw"

# Os dez arquivos que o ERP e o CRM têm que entregar todo dia.
ESPERADOS = {
    "erp": ["produtos", "pedidos", "itens_pedido", "pagamentos", "estoque"],
    "crm": ["clientes", "vendedores", "carteira", "oportunidades", "visitas"],
}

# COMMAND ----------

from pyspark.sql import functions as F

linhas_controle = []
faltando = []
vazios = []

for sistema, tabelas in ESPERADOS.items():
    # dbutils.fs.ls falha se a pasta não existir — o que já é uma resposta.
    try:
        presentes = {a.name: a for a in dbutils.fs.ls(f"{RAIZ}/{sistema}")}
    except Exception:
        presentes = {}

    for tabela in tabelas:
        arquivo = f"{tabela}.csv"
        info = presentes.get(arquivo)
        if info is None:
            faltando.append(f"{sistema}/{arquivo}")
            continue
        if info.size == 0:
            vazios.append(f"{sistema}/{arquivo}")

        # Conta linha de dado: o total do arquivo menos a linha de cabeçalho.
        total = spark.read.text(f"{RAIZ}/{sistema}/{arquivo}").count() - 1
        linhas_controle.append((sistema, arquivo, int(info.size), int(total)))

# COMMAND ----------

# A tabela de controle é o registro de que o dado chegou. Ela é consultada no
# prompt seguinte: a bronze só aceita a contagem que bate com a daqui.
controle = (
    spark.createDataFrame(linhas_controle, "sistema string, arquivo string, bytes long, linhas long")
    .withColumn("conferido_em", F.current_timestamp())
)

controle.write.mode("overwrite").option("overwriteSchema", "true").saveAsTable(
    f"{catalog}.bronze._raw_arquivos"
)

spark.sql(
    f"COMMENT ON TABLE {catalog}.bronze._raw_arquivos IS "
    "'Controle de chegada do raw: um registro por arquivo recebido no Volume, "
    "com tamanho e contagem de linhas. Escrita pela tarefa raw_conferencia.'"
)

# COMMAND ----------

print(f"{'sistema':<8} {'arquivo':<22} {'bytes':>12} {'linhas':>10}")
print("-" * 56)
for sistema, arquivo, tamanho, total in sorted(linhas_controle, key=lambda r: -r[3]):
    print(f"{sistema:<8} {arquivo:<22} {tamanho:>12,} {total:>10,}")
print("-" * 56)
print(f"{'TOTAL':<31} {sum(r[2] for r in linhas_controle):>12,} {sum(r[3] for r in linhas_controle):>10,}")

# COMMAND ----------

# Falhar aqui é o ponto da tarefa. Pipeline que segue com arquivo faltando é
# pior do que pipeline nenhum.
if faltando:
    raise Exception(f"Arquivos que não chegaram no Volume: {', '.join(faltando)}")
if vazios:
    raise Exception(f"Arquivos que chegaram vazios: {', '.join(vazios)}")

print(f"\nOK — os 10 arquivos chegaram em {RAIZ}")
