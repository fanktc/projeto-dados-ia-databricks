"""Exemplo 06 · O agente comercial — o dado vira ação.

Conceito: ferramentas sobre tabelas, decisão explicável, recusa por falta de dado
Pergunta de negócio: o que o vendedor faz hoje de manhã?

A diferença entre um agente e um chatbot não é o modelo de linguagem: é de
onde vem o número. Este agente não sabe nada sobre a Rota do Perfume — ele
só sabe chamar três ferramentas que consultam as tabelas das noites 1 a 3.

Se a ferramenta não achar dado, ele diz que não sabe. Não estima.

    cd aulas/aula-04-deploy/perfumesarabe
    export DATABRICKS_CONFIG_PROFILE=SEU-PERFIL DATABRICKS_SERVERLESS_COMPUTE_ID=auto
    .venv/bin/python ../../aula-03-ciencia-de-dados-e-agentes/exemplo-06-agente-comercial.py
"""

from databricks.connect import DatabricksSession

CAT = "lakehouse_rotaperfume"
HOJE = "DATE'2026-08-31'"
spark = DatabricksSession.builder.getOrCreate()


# ═══════════════════════════════════════════════════════════════════
# AS FERRAMENTAS — cada uma é uma query, e só devolve o que existe
# ═══════════════════════════════════════════════════════════════════

def priorizar_carteira(vendedor_id: int, limite: int = 5) -> list[dict]:
    """Quem esse vendedor deve procurar hoje, e por quê."""
    return spark.sql(f"""
        SELECT
            c.cliente_id,
            c.razao_social                                   AS cliente,
            c.cidade,
            ROUND(s.score_propensao, 3)                      AS score,
            s.faixa,
            f.recencia_dias,
            f.ritmo_dias,
            ROUND(f.ticket_medio, 2)                         AS ticket_medio,
            CASE
                WHEN f.atraso_relativo > 2   THEN 'Atrasado — risco de perder'
                WHEN s.faixa = 'Muito quente' THEN 'Alta chance de comprar agora'
                WHEN f.valor_total > 50000    THEN 'Cliente grande, manter próximo'
                ELSE                               'Rotina de carteira'
            END                                              AS motivo
        FROM {CAT}.gold.score_propensao s
        JOIN {CAT}.gold.features_cliente f ON f.cliente_id = s.cliente_id
        JOIN {CAT}.gold.dim_cliente     c ON c.cliente_id = s.cliente_id
        WHERE c.vendedor_atual_id = {vendedor_id}
        ORDER BY s.score_propensao DESC
        LIMIT {limite}
    """).toPandas().to_dict("records")


def checar_disponibilidade(sku: str) -> dict | None:
    """O produto que vou oferecer está disponível?

    Devolve None quando o SKU não tem snapshot recente — e isso é uma
    resposta legítima. O estoque cobre só 27% das semanas por SKU.
    """
    r = spark.sql(f"""
        SELECT sku, CAST(saldo AS INT) AS saldo, ruptura = 'S' AS em_ruptura,
               data_snapshot
        FROM {CAT}.bronze.estoque
        WHERE sku = '{sku}'
        ORDER BY data_snapshot DESC
        LIMIT 1
    """).toPandas().to_dict("records")
    return r[0] if r else None


def sugerir_produtos(cliente_id: int, limite: int = 3) -> list[dict]:
    """O que ele costuma comprar e não compra há mais de 60 dias."""
    return spark.sql(f"""
        SELECT sku, marca, categoria,
               SUM(quantidade)          AS qtd_historica,
               MAX(data_pedido)         AS ultima_compra,
               datediff({HOJE}, MAX(data_pedido)) AS dias_sem_comprar
        FROM {CAT}.gold.fato_vendas
        WHERE cliente_id = {cliente_id} AND NOT devolucao
        GROUP BY sku, marca, categoria
        HAVING datediff({HOJE}, MAX(data_pedido)) > 60
        ORDER BY qtd_historica DESC
        LIMIT {limite}
    """).toPandas().to_dict("records")


FERRAMENTAS = {
    "priorizar_carteira": priorizar_carteira,
    "checar_disponibilidade": checar_disponibilidade,
    "sugerir_produtos": sugerir_produtos,
}

# A instrução que iria para o modelo de linguagem. O que segura o agente não
# é o modelo ser bom: são estas regras.
INSTRUCAO = """
Você é o assistente comercial da Rota do Perfume.
Seu trabalho é dizer ao vendedor quem procurar hoje e o que oferecer.

Regras:
- Use SEMPRE as ferramentas. Nunca invente cliente, score ou saldo.
- Antes de sugerir um produto, cheque a disponibilidade em estoque.
- Explique o motivo em uma frase, na linguagem do vendedor.
- Se não houver dado suficiente, diga isso em vez de estimar.
"""


# ═══════════════════════════════════════════════════════════════════
# O AGENTE — aqui sem LLM: a decisão é a sequência de ferramentas
# ═══════════════════════════════════════════════════════════════════

def briefing_do_dia(vendedor_id: int) -> None:
    vendedor = spark.sql(
        f"SELECT nome, regiao, meta_mensal FROM {CAT}.gold.dim_vendedor "
        f"WHERE vendedor_id = {vendedor_id}"
    ).toPandas().to_dict("records")

    if not vendedor:
        print(f"Vendedor {vendedor_id} não existe. Não vou adivinhar.")
        return

    v = vendedor[0]
    print(f"\n{'=' * 68}")
    print(f"BRIEFING · {v['nome']} · {v['regiao']} · meta R$ {v['meta_mensal']:,.2f}")
    print("=" * 68)

    carteira = priorizar_carteira(vendedor_id)
    if not carteira:
        print("\nSem cliente com score nesta carteira. Rode o exemplo 05 antes.")
        return

    for i, c in enumerate(carteira, 1):
        print(f"\n{i}. {c['cliente']} · {c['cidade']}")
        print(f"   score {c['score']} ({c['faixa']}) · ticket médio R$ {c['ticket_medio']:,.2f}")
        print(f"   compra a cada {c['ritmo_dias']:.0f} dias, parado há {c['recencia_dias']}")
        print(f"   → {c['motivo']}")

        sugestoes = sugerir_produtos(c["cliente_id"])
        if not sugestoes:
            print("   sem produto para reoferecer (comprou tudo recentemente)")
            continue

        for s in sugestoes:
            estoque = checar_disponibilidade(s["sku"])
            if estoque is None:
                situacao = "sem snapshot de estoque — confirmar no ERP"
            elif estoque["em_ruptura"]:
                situacao = "EM RUPTURA — não ofereça"
            else:
                situacao = f"{estoque['saldo']} em estoque"
            print(f"   · {s['sku']} {s['marca']:<12} {s['categoria']:<20} "
                  f"{s['dias_sem_comprar']:>4}d sem comprar · {situacao}")


def main() -> None:
    # o vendedor com mais clientes na carteira
    alvo = spark.sql(
        f"SELECT vendedor_id FROM {CAT}.gold.dim_vendedor "
        f"WHERE ativo ORDER BY clientes_na_carteira DESC LIMIT 1"
    ).toPandas().iloc[0]["vendedor_id"]

    briefing_do_dia(int(alvo))

    print(f"\n{'=' * 68}")
    print("Repare: todo número acima saiu de uma tabela. O agente não estimou\n"
          "nada — e quando faltou snapshot de estoque, ele disse que faltou.")
    print("=" * 68)


if __name__ == "__main__":
    main()
