"""Explorer 3 · Quanto vamos vender?

Previsão de série temporal precisa de três coisas: pontos suficientes, um
padrão que se repita e uma tendência estável. Este explorer mede as três.

    python3 notebooks/n3_explorer_previsao.py
"""

import statistics
from collections import defaultdict

from comum import pedidos_por_cliente, titulo, veredito

MES = ["", "jan", "fev", "mar", "abr", "mai", "jun",
       "jul", "ago", "set", "out", "nov", "dez"]


def main() -> None:
    titulo("EXPLORER 3 · PREVISÃO", "Quanto vamos vender?")
    ped = pedidos_por_cliente()

    mensal, semanal, diario = defaultdict(float), defaultdict(float), defaultdict(float)
    for v in ped.values():
        for data, valor in v:
            mensal[(data.year, data.month)] += valor
            semanal[data.isocalendar()[:2]] += valor
            diario[data] += valor

    # ---------------------------------------------------------------
    print("\n1. QUANTOS PONTOS EXISTEM PARA APRENDER\n")
    print(f"  mensal   {len(mensal):>4} pontos   = {len(mensal)/12:.1f} ciclos anuais")
    print(f"  semanal  {len(semanal):>4} pontos")
    print(f"  diário   {len(diario):>4} pontos")
    print("\n  Para aprender sazonalidade anual são precisos pelo menos dois")
    print("  ciclos. Temos exatamente dois — o mínimo, sem folga para validar")
    print("  num terceiro. Na granularidade mensal isso é apertado.")

    # ---------------------------------------------------------------
    print("\n\n2. A SAZONALIDADE SE REPETE?\n")
    chaves = sorted(mensal)
    ano1 = {k[1]: mensal[k] for k in chaves[:12]}
    ano2 = {k[1]: mensal[k] for k in chaves[12:]}
    comuns = sorted(set(ano1) & set(ano2))
    print(f"  {'mês':<6}{'ano 1':>12}{'ano 2':>12}   variação")
    for m in comuns:
        var = 100 * (ano2[m] / ano1[m] - 1)
        print(f"  {MES[m]:<6}{ano1[m]/1e6:>10.2f} mi{ano2[m]/1e6:>10.2f} mi   {var:>+6.0f}%")

    # o mesmo mês é pico nos dois anos?
    pico1, pico2 = max(ano1, key=ano1.get), max(ano2, key=ano2.get)
    vale1, vale2 = min(ano1, key=ano1.get), min(ano2, key=ano2.get)
    print(f"\n  pico:  ano 1 = {MES[pico1]}   ano 2 = {MES[pico2]}"
          f"   {'-> se repete' if pico1 == pico2 else '-> NÃO se repete'}")
    print(f"  vale:  ano 1 = {MES[vale1]}   ano 2 = {MES[vale2]}"
          f"   {'-> se repete' if vale1 == vale2 else '-> NÃO se repete'}")

    # ---------------------------------------------------------------
    print("\n\n3. EXISTE TENDÊNCIA DE CRESCIMENTO?\n")
    t1, t2 = sum(ano1.values()), sum(ano2.values())
    print(f"  12 meses iniciais: R$ {t1/1e6:>6.1f} mi")
    print(f"  12 meses finais:   R$ {t2/1e6:>6.1f} mi")
    print(f"  crescimento:       {100*(t2/t1-1):>+6.0f}%")

    primeiro = mensal[chaves[0]]
    demais = statistics.median([mensal[k] for k in chaves[1:]])
    print(f"\n  ATENÇÃO ao primeiro mês: {MES[chaves[0][1]]}/{chaves[0][0]} fez "
          f"R$ {primeiro/1e6:.2f} mi contra mediana de R$ {demais/1e6:.2f} mi.")
    print("  É artefato do gerador — todo cliente entra na base com um pedido,")
    print("  o que infla setembro/2024 e esvazia os meses seguintes.")
    # Comparação justa: as mesmas 11 janelas (out a ago) de cada ano, para o
    # mês de cold start não entrar em nenhum dos dois lados.
    limpo1 = sum(mensal[k] for k in chaves[1:12])
    limpo2 = sum(mensal[k] for k in chaves[13:24])
    print(f"\n  Comparando out-ago de cada ano (11 meses contra 11, sem cold start):")
    print(f"    R$ {limpo1/1e6:.1f} mi  ->  R$ {limpo2/1e6:.1f} mi   "
          f"{100*(limpo2/limpo1-1):+.0f}%")
    print("\n  Ou seja: a série é sazonal, não é crescente. A documentação do")
    print("  dataset diz que 'a receita mais que dobrou' — no dado medido,")
    print("  ela está praticamente estável ano contra ano.")

    # ---------------------------------------------------------------
    print("\n\n4. QUANTO DA VARIAÇÃO O MÊS EXPLICA\n")
    todos = list(mensal.values())
    media = statistics.mean(todos)
    var_total = statistics.pvariance(todos)
    por_mes = defaultdict(list)
    for (_, m), v in mensal.items():
        por_mes[m].append(v)
    var_entre = sum(len(v) * (statistics.mean(v) - media) ** 2
                    for v in por_mes.values()) / len(todos)
    print(f"  variação explicada pelo mês do ano: {100*var_entre/var_total:.0f}%")
    print("  O resto é tendência, ruído e efeito de lançamento.")

    # ---------------------------------------------------------------
    veredito(
        "SIM, mas com três ressalvas que mudam o desenho do modelo.",
        "  O mês do ano explica 87% da variação da receita: há padrão, e ele é\n"
        "  aprendível. O vale de janeiro se repete nos dois anos, exatamente\n"
        "  como o negócio prevê.\n\n"
        "  RESSALVAS:\n"
        "  1. O PICO NÃO SE REPETE na comparação bruta: abril no primeiro ano,\n"
        "     outubro no segundo. A causa é o cold start de set/2024, que rouba\n"
        "     pedido de outubro. Descarte os 2 primeiros meses antes de treinar.\n"
        "  2. São 24 pontos mensais = 2 ciclos, o mínimo absoluto, sem um\n"
        "     terceiro ano para validar. Prefira granularidade semanal\n"
        "     (106 pontos) usando o mês como feature.\n"
        "  3. Não há tendência de crescimento para extrapolar. Um modelo que\n"
        "     projeta crescimento vai errar para cima.\n\n"
        "  Previsão honesta aqui: sazonal, horizonte curto de 1 a 3 meses.")


if __name__ == "__main__":
    main()
