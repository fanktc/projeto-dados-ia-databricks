"""Leitura dos CSVs da Rota do Perfume, compartilhada pelos explorers.

Tudo com biblioteca padrão: os explorers precisam rodar na máquina de
qualquer aluno, com ou sem Databricks.
"""

import csv
from collections import defaultdict
from datetime import date, datetime
from pathlib import Path

RAIZ = Path(__file__).resolve().parent.parent / "dados"

# O "hoje" do dataset. O gerador para em 31/08/2026, então é essa a data que
# faz sentido usar como referência — não a data real de quem está rodando.
HOJE = date(2026, 8, 31)


def ler_data(texto: str) -> date | None:
    """A data vem em dois formatos: ISO e brasileiro. Tenta os dois."""
    for formato in ("%Y-%m-%d", "%d/%m/%Y"):
        try:
            return datetime.strptime(texto.strip(), formato).date()
        except ValueError:
            continue
    return None


def ler(caminho: str) -> list[dict]:
    with open(RAIZ / caminho, newline="", encoding="utf-8") as f:
        return list(csv.DictReader(f))


def pedidos_por_cliente() -> dict[int, list[tuple[date, float]]]:
    """Pedidos faturados de cada cliente, sem os cancelados."""
    por_cliente = defaultdict(list)
    for r in ler("erp/pedidos.csv"):
        if r["status"] == "Cancelado":
            continue
        data = ler_data(r["data_pedido"])
        if data:
            por_cliente[int(r["cliente_id"])].append((data, float(r["valor_total"])))
    for v in por_cliente.values():
        v.sort()
    return dict(por_cliente)


def titulo(texto: str, pergunta: str) -> None:
    print(f"\n{'=' * 72}\n{texto}\n{pergunta}\n{'=' * 72}")


def veredito(resposta: str, motivo: str) -> None:
    print(f"\n{'-' * 72}\nRESPOSTA: {resposta}\n{motivo}\n{'-' * 72}")
