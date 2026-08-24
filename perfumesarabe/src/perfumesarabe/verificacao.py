"""Testes que quebram o pipeline antes de quebrar o dashboard.

Rodam depois de cada carga. A ideia não é provar que o código roda — é provar
que o número que vai para a tela do gestor é o número certo.

Duas famílias de checagem:

1. Os números-âncora do negócio. O dataset tem seed fixa, então receita,
   ticket médio e pico de outubro são valores conhecidos. Se a query
   divergir, o erro está na query, não no dado.
2. A sujeira que a bronze tem obrigação de preservar. Se o CNPJ com espaço
   sumiu, alguém "limpou" a bronze — e a evidência da origem foi perdida.
"""

from pyspark.sql import SparkSession

# A data vem em dois formatos. try_to_date devolve NULL em vez de derrubar a
# query, então o coalesce pode tentar um depois do outro.
DATA_PEDIDO = (
    "coalesce(try_to_date(data_pedido, 'yyyy-MM-dd'), "
    "try_to_date(data_pedido, 'dd/MM/yyyy'))"
)


def _checagens(catalog: str, schema: str) -> list[tuple[str, str, str]]:
    """(nome, SQL que devolve um valor, condição sobre esse valor)."""
    b = f"`{catalog}`.`{schema}`"
    faturados = f"SELECT CAST(valor_total AS DECIMAL(18,2)) v, {DATA_PEDIDO} d FROM {b}.pedidos WHERE status <> 'Cancelado'"
    return [
        (
            "receita total (24 meses)",
            f"SELECT ROUND(SUM(v), 2) FROM ({faturados})",
            "100e6 <= x <= 104e6",
        ),
        (
            "pedidos faturados",
            f"SELECT COUNT(*) FROM ({faturados})",
            "x == 27772",
        ),
        (
            "ticket médio por pedido",
            f"SELECT ROUND(SUM(v)/COUNT(*), 2) FROM ({faturados})",
            "3600 <= x <= 3760",
        ),
        (
            "receita de outubro/2025",
            f"SELECT ROUND(SUM(v), 2) FROM ({faturados}) WHERE date_trunc('month', d) = DATE'2025-10-01'",
            "6.8e6 <= x <= 7.2e6",
        ),
        (
            "nenhuma data ilegível",
            f"SELECT COUNT(*) FROM {b}.pedidos WHERE {DATA_PEDIDO} IS NULL",
            "x == 0",
        ),
        (
            "sujeira preservada: datas em dd/MM/yyyy",
            f"SELECT COUNT(*) FROM {b}.pedidos WHERE data_pedido LIKE '%/%'",
            "x == 3443",
        ),
        (
            "sujeira preservada: CNPJ com espaço",
            f"SELECT COUNT(*) FROM {b}.clientes WHERE cnpj <> trim(cnpj)",
            "x == 223",
        ),
        (
            "sujeira preservada: devoluções",
            f"SELECT COUNT(*) FROM {b}.itens_pedido WHERE CAST(quantidade AS INT) < 0",
            "x == 2327",
        ),
        (
            "sujeira preservada: CNPJ duplicado",
            f"SELECT COUNT(*) FROM (SELECT regexp_replace(trim(cnpj), '[^0-9]', '') c "
            f"FROM {b}.clientes GROUP BY 1 HAVING COUNT(*) > 1)",
            "x == 40",
        ),
    ]


def verificar(spark: SparkSession, catalog: str, schema: str) -> list[str]:
    """Roda todas as checagens. Devolve a lista das que falharam."""
    falhas = []
    for nome, sql, condicao in _checagens(catalog, schema):
        x = spark.sql(sql).collect()[0][0]
        passou = eval(condicao, {"x": float(x) if x is not None else None})  # noqa: S307
        print(f"  {'ok  ' if passou else 'FALHOU'}  {nome:<42} {x}")
        if not passou:
            falhas.append(f"{nome}: obtido {x}, esperado {condicao}")
    return falhas
