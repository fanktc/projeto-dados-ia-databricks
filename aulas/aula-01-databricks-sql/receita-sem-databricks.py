"""Noite 1 · Receita por mês, direto do CSV.

Este script responde a pergunta da noite — "qual foi nossa receita?" — sem
Databricks nenhum. Roda na máquina de qualquer aluno, só com a biblioteca
padrão do Python. É o plano B se o workspace cair no meio da aula.

O ponto de atenção é o mesmo do SQL: 12% das datas vêm em dd/mm/aaaa em vez
de aaaa-mm-dd. Ignorar isso não dá erro aqui — dá um número menor, em
silêncio, que é bem pior.

Uso:
    python3 aulas/aula-01-databricks-sql/receita-sem-databricks.py
    python3 aulas/aula-01-databricks-sql/receita-sem-databricks.py --csv dados/erp/pedidos.csv
"""

import argparse
import csv
from pathlib import Path

# a raiz do repositório, a partir deste arquivo
RAIZ = Path(__file__).resolve().parent.parent.parent
from collections import defaultdict
from datetime import datetime
from decimal import Decimal


def ler_data(texto: str):
    """A data vem em dois formatos. Tenta os dois, na ordem."""
    for formato in ("%Y-%m-%d", "%d/%m/%Y"):
        try:
            return datetime.strptime(texto.strip(), formato).date()
        except ValueError:
            continue
    return None


def receita_por_mes(caminho: str):
    """Soma a receita por mês, ignorando pedido cancelado."""
    receita = defaultdict(Decimal)
    pedidos = defaultdict(int)
    ignorados = 0
    cancelados = 0

    with open(caminho, newline="", encoding="utf-8") as f:
        for linha in csv.DictReader(f):
            if linha["status"] == "Cancelado":
                # Cancelado tem valor_total zerado. Somar não mudaria o total,
                # mas contaria um pedido que não aconteceu.
                cancelados += 1
                continue
            data = ler_data(linha["data_pedido"])
            if data is None:
                ignorados += 1
                continue
            chave = (data.year, data.month)
            receita[chave] += Decimal(linha["valor_total"])
            pedidos[chave] += 1

    return receita, pedidos, ignorados, cancelados


def grafico_ascii(receita: dict, largura: int = 46) -> str:
    """Um gráfico de barras que funciona em qualquer terminal, sem dependência."""
    if not receita:
        return "(sem dados)"
    teto = max(receita.values())
    linhas = []
    for (ano, mes) in sorted(receita):
        valor = receita[(ano, mes)]
        barra = "█" * max(1, int(largura * valor / teto))
        linhas.append(f"  {ano}-{mes:02d}  {barra} {valor / 1_000_000:>5.2f} mi")
    return "\n".join(linhas)


def salvar_png(receita: dict, destino: str) -> str | None:
    """PNG só se o matplotlib estiver instalado. Não é requisito."""
    try:
        import matplotlib
        matplotlib.use("Agg")
        import matplotlib.pyplot as plt
    except ImportError:
        return None

    chaves = sorted(receita)
    rotulos = [f"{a}-{m:02d}" for a, m in chaves]
    valores = [float(receita[k]) / 1_000_000 for k in chaves]

    fig, ax = plt.subplots(figsize=(13, 5))
    ax.bar(rotulos, valores, color="#7c3f5e")
    ax.set_title("Rota do Perfume — receita por mês")
    ax.set_ylabel("R$ milhões")
    ax.tick_params(axis="x", rotation=60, labelsize=8)
    ax.grid(axis="y", alpha=0.3)
    fig.tight_layout()
    fig.savefig(destino, dpi=130)
    return destino


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--csv", default=str(RAIZ / "dados/erp/pedidos.csv"))
    ap.add_argument("--png", default=str(RAIZ / "receita-por-mes.png"))
    args = ap.parse_args()

    receita, pedidos, ignorados, cancelados = receita_por_mes(args.csv)
    total = sum(receita.values())
    n_pedidos = sum(pedidos.values())

    print(f"\nReceita por mês — {args.csv}\n")
    print(grafico_ascii(receita))

    print(f"\n  Receita total     R$ {total:,.2f}")
    print(f"  Pedidos           {n_pedidos:,}")
    print(f"  Ticket médio      R$ {total / n_pedidos:,.2f}")
    print(f"  Cancelados fora   {cancelados:,}")

    # Se este número não for zero, alguma data escapou dos dois formatos
    # conhecidos — e a receita acima está incompleta.
    print(f"  Datas ilegíveis   {ignorados:,}")

    # O pico é o mês ANTERIOR à data comemorativa: o varejo compra antes.
    pico = max(receita, key=receita.get)
    vale = min(receita, key=receita.get)
    print(f"\n  Melhor mês        {pico[0]}-{pico[1]:02d}  R$ {receita[pico]:,.2f}")
    print(f"  Pior mês          {vale[0]}-{vale[1]:02d}  R$ {receita[vale]:,.2f}")

    destino = salvar_png(receita, args.png)
    print(f"\n  Gráfico           {destino}" if destino
          else "\n  (instale matplotlib para gerar o PNG; o gráfico acima já responde)")


if __name__ == "__main__":
    main()
