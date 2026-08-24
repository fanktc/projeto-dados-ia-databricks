"""Testes da ingestão bronze.

Os testes de contrato rodam sem Databricks. Os que tocam o dado precisam de
workspace (o conftest cai para serverless quando nenhum compute é informado).
"""

from perfumesarabe import ingestao


def test_toda_tabela_tem_contagem_esperada():
    """Se alguém adicionar uma tabela e esquecer a âncora, o teste avisa."""
    assert set(ingestao.TABELAS) == set(ingestao.LINHAS_ESPERADAS)


def test_subpastas_conhecidas():
    assert set(ingestao.TABELAS.values()) == {"erp", "crm"}


def test_caminho_do_volume():
    assert ingestao.caminho_volume("lakehouse_rotaperfume", "bronze") == (
        "/Volumes/lakehouse_rotaperfume/bronze/raw"
    )


def test_bronze_tem_a_volumetria_esperada(spark):
    """A bronze precisa estar ingerida — rode o job antes."""
    for tabela, esperado in ingestao.LINHAS_ESPERADAS.items():
        n = spark.table(f"lakehouse_rotaperfume.bronze.{tabela}").count()
        assert n == esperado, f"{tabela}: {n} linhas, esperava {esperado}"


def test_bronze_e_toda_texto(spark):
    """Se alguma coluna virou número, a sujeira da origem foi perdida."""
    for tabela in ingestao.TABELAS:
        df = spark.table(f"lakehouse_rotaperfume.bronze.{tabela}")
        tipos = {
            campo.name: campo.dataType.simpleString()
            for campo in df.schema.fields
            if not campo.name.startswith("_")
        }
        nao_texto = {c: t for c, t in tipos.items() if t != "string"}
        assert not nao_texto, f"{tabela} tem coluna não-texto: {nao_texto}"
