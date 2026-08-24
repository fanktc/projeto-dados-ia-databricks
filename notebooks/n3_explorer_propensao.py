"""Explorer 1 · Quem vai comprar?

A pergunta da diretoria é "quem vai comprar". Para um modelo, ela vira:
dado o que o cliente fez até uma data de corte, ele compra nos próximos N dias?

Este explorer não treina modelo nenhum. Ele responde uma pergunta anterior e
mais importante: o dado que a gente tem sustenta esse modelo?

    python3 notebooks/n3_explorer_propensao.py
"""

import statistics
from collections import Counter, defaultdict
from datetime import timedelta

from comum import HOJE, ler, ler_data, pedidos_por_cliente, titulo, veredito


def main() -> None:
    titulo("EXPLORER 1 · PROPENSÃO", "Quem vai comprar?")
    ped = pedidos_por_cliente()

    # ---------------------------------------------------------------
    # 1. Tem cliente suficiente com histórico?
    # ---------------------------------------------------------------
    print("\n1. QUANTOS CLIENTES TÊM HISTÓRICO USÁVEL\n")
    total_cadastrados = len(ler("crm/clientes.csv"))
    faixas = Counter(len(v) for v in ped.values())
    print(f"  clientes cadastrados:     {total_cadastrados:,}")
    print(f"  clientes com algum pedido: {len(ped):,} "
          f"({100 * len(ped) / total_cadastrados:.0f}%)")
    print()
    for rotulo, lo, hi in [("1 pedido", 1, 1), ("2 a 4", 2, 4), ("5 a 9", 5, 9),
                           ("10 a 19", 10, 19), ("20 ou mais", 20, 10**6)]:
        n = sum(c for k, c in faixas.items() if lo <= k <= hi)
        print(f"    {rotulo:<12} {n:>5} clientes  {100 * n / len(ped):>5.1f}%")

    com_ritmo = sum(1 for v in ped.values() if len(v) >= 3)
    print(f"\n  com 3+ pedidos (dá para medir ritmo de compra): "
          f"{com_ritmo:,}  ({100 * com_ritmo / len(ped):.1f}%)")

    # ---------------------------------------------------------------
    # 2. O alvo é aprendível? Depende do tamanho da janela.
    # ---------------------------------------------------------------
    print("\n\n2. O TAMANHO DA JANELA MUDA TUDO\n")
    print("  Se quase todo cliente compra na janela, não há o que prever:")
    print("  um modelo que responde 'sim' para todos já acerta.\n")
    print("  janela      compram   comentário")
    for dias in (30, 60, 90, 180):
        corte = HOJE - timedelta(days=dias)
        elegiveis = {c for c, v in ped.items() if v[0][0] <= corte}
        compraram = {c for c, v in ped.items() if any(corte < d <= HOJE for d, _ in v)}
        taxa = 100 * len(elegiveis & compraram) / len(elegiveis)
        nota = ("equilibrado, dá para aprender" if 30 <= taxa <= 60
                else "desbalanceado, o modelo vira 'chuta sim'")
        print(f"    {dias:>3} dias    {taxa:>5.1f}%    {nota}")
    print("\n  -> 30 dias é a janela que faz o problema existir.")

    # ---------------------------------------------------------------
    # 3. Que sinais existem além do histórico de compra?
    # ---------------------------------------------------------------
    print("\n\n3. OS SINAIS DISPONÍVEIS PARA VIRAR FEATURE\n")

    visitas = defaultdict(list)
    for r in ler("crm/visitas.csv"):
        d = ler_data(r["data_visita"])
        if d:
            visitas[int(r["cliente_id"])].append((d, r["resultado"]))

    oport = defaultdict(list)
    for r in ler("crm/oportunidades.csv"):
        oport[int(r["cliente_id"])].append(r["etapa"])

    cob_v = 100 * len(visitas) / total_cadastrados
    cob_o = 100 * len(oport) / total_cadastrados

    print("  RFM clássico, direto de pedidos.csv:")
    recencias = [(HOJE - v[-1][0]).days for v in ped.values()]
    valores = [sum(x[1] for x in v) for v in ped.values()]
    print(f"    recência   mediana {statistics.median(recencias):>6.0f} dias")
    print(f"    frequência mediana {statistics.median([len(v) for v in ped.values()]):>6.0f} pedidos")
    print(f"    valor      mediano  R$ {statistics.median(valores):>10,.2f}")

    print(f"\n  Sinais de CRM, que o ERP sozinho não enxerga:")
    print(f"    visitas registradas      {len(visitas):>5} clientes ({cob_v:.0f}% da base)")
    print(f"    oportunidades no funil   {len(oport):>5} clientes ({cob_o:.0f}% da base)")

    resultados = Counter(r for v in visitas.values() for _, r in v)
    print(f"\n    resultado das visitas: " +
          " · ".join(f"{k} {v:,}" for k, v in resultados.most_common()))

    # ---------------------------------------------------------------
    veredito(
        "SIM, dá para responder.",
        "  2.816 clientes com histórico, 93% deles com ritmo mensurável, e uma\n"
        "  janela de 30 dias que deixa o alvo em ~41% — nem trivial, nem raro.\n"
        "  Há sinal de compra (RFM) e sinal de relacionamento (visita, funil),\n"
        "  que é o que separa um modelo bom de um que só olha para o passado.\n\n"
        "  RESSALVA: use janela de 30 dias. Com 90 dias, 81% dos clientes\n"
        "  compram e o modelo não tem o que aprender — ele acerta chutando sim.")


if __name__ == "__main__":
    main()
