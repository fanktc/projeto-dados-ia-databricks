"""Explorer 2 · Quem está sumindo?

Churn numa distribuidora B2B não é cancelamento: ninguém avisa que parou de
comprar. O cliente simplesmente deixa de aparecer.

Por isso não existe uma coluna "churn" para consultar — a definição é uma
decisão de negócio, e é ela que este explorer procura.

    python3 notebooks/n3_explorer_churn.py
"""

import statistics
from collections import Counter

from comum import HOJE, pedidos_por_cliente, titulo, veredito


def ritmo(datas: list) -> float:
    """Mediana do intervalo entre compras — o 'relógio' daquele cliente."""
    return statistics.median([(b - a).days for a, b in zip(datas, datas[1:])])


def main() -> None:
    titulo("EXPLORER 2 · CHURN", "Quem está sumindo?")
    ped = pedidos_por_cliente()

    # ---------------------------------------------------------------
    print("\n1. NÃO EXISTE COLUNA DE CHURN. EXISTE RITMO.\n")
    com_ritmo = {c: [d for d, _ in v] for c, v in ped.items() if len(v) >= 3}
    ritmos = {c: ritmo(d) for c, d in com_ritmo.items()}
    valores = sorted(ritmos.values())
    print(f"  clientes com 3+ pedidos: {len(com_ritmo):,} de {len(ped):,}")
    print(f"\n  intervalo típico entre compras:")
    print(f"    p10  {valores[len(valores)//10]:>4.0f} dias   (os que compram sempre)")
    print(f"    mediana {statistics.median(valores):>4.0f} dias")
    print(f"    p90  {valores[9*len(valores)//10]:>4.0f} dias   (os de compra esparsa)")
    print("\n  Repare na dispersão: um cliente que some por 90 dias pode estar")
    print("  atrasado ou pode estar no ritmo dele. Um corte fixo trata os dois")
    print("  do mesmo jeito — e é por isso que ele erra.")

    # ---------------------------------------------------------------
    print("\n\n2. CORTE FIXO CONTRA CORTE RELATIVO\n")
    recencia = {c: (HOJE - d[-1]).days for c, d in com_ritmo.items()}

    print("  (a) corte fixo — 'sem comprar há X dias'")
    for dias in (60, 90, 120, 180):
        n = sum(1 for r in recencia.values() if r > dias)
        print(f"      > {dias:>3} dias: {n:>5} clientes  ({100*n/len(recencia):>4.1f}%)")

    print("\n  (b) corte relativo — 'atrasado em relação ao próprio ritmo'")
    for fator in (1.5, 2.0, 2.5, 3.0):
        n = sum(1 for c in com_ritmo if recencia[c] > fator * ritmos[c])
        print(f"      > {fator:.1f}x o ritmo: {n:>5} clientes  ({100*n/len(recencia):>4.1f}%)")

    # quem os dois métodos discordam
    fixo = {c for c in com_ritmo if recencia[c] > 90}
    rel = {c for c in com_ritmo if recencia[c] > 2.5 * ritmos[c]}
    print(f"\n  Os dois métodos discordam em {len(fixo ^ rel):,} clientes:")
    print(f"    {len(fixo - rel):>4} o corte fixo acusa, mas estão no ritmo deles")
    print(f"    {len(rel - fixo):>4} o corte fixo ignora, mas estão atrasados de verdade")

    # ---------------------------------------------------------------
    print("\n\n3. QUEM ESTÁ SUMINDO, E QUANTO ISSO VALE\n")
    em_risco = sorted(rel, key=lambda c: -sum(v for _, v in ped[c]))
    receita_risco = sum(sum(v for _, v in ped[c]) for c in em_risco)
    print(f"  clientes atrasados (>2,5x o próprio ritmo): {len(em_risco):,}")
    print(f"  receita histórica desses clientes: R$ {receita_risco:,.2f}")
    print(f"\n  os 5 maiores em risco:")
    print(f"    {'cliente':>8}  {'histórico':>14}  {'ritmo':>7}  {'parado há':>10}")
    for c in em_risco[:5]:
        print(f"    {c:>8}  R$ {sum(v for _, v in ped[c]):>11,.0f}  "
              f"{ritmos[c]:>4.0f} d  {recencia[c]:>7} d")

    # a base tem churn de verdade?
    nunca_voltou = sum(1 for c in com_ritmo if recencia[c] > 365)
    print(f"\n  clientes parados há mais de um ano: {nunca_voltou:,} "
          f"({100*nunca_voltou/len(com_ritmo):.1f}%)")

    # ---------------------------------------------------------------
    veredito(
        "SIM, dá para responder — mas a definição é sua, não do dado.",
        "  O dado dá o que é preciso: 2.623 clientes com ritmo mensurável e\n"
        "  recência calculável para todos. O que ele não dá é o rótulo.\n\n"
        "  A escolha que importa é entre corte fixo e corte relativo, e ela\n"
        "  muda quem entra na lista. Corte relativo é o certo aqui: o cliente\n"
        "  que compra a cada 30 dias e sumiu há 80 está em risco; o que compra\n"
        "  a cada 110 e sumiu há 80 está apenas no ritmo dele.\n\n"
        "  RESSALVA: 6,5% de clientes atrasados é pouco para treinar um\n"
        "  classificador de churn com folga. Para a noite 3, prefira tratar\n"
        "  churn como REGRA sobre o ritmo, e deixe o modelo para a propensão.")


if __name__ == "__main__":
    main()
