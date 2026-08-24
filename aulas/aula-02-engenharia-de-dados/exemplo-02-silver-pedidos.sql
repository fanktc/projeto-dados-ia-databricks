-- ============================================
-- EXEMPLO 02: Silver de pedidos — a data e o cancelado
-- ============================================
-- Conceito: coalesce com try_to_date, flag explícita, tipagem
-- Pergunta de negócio: quais pedidos entram na receita?
-- Conexão com a aula 03: data_pedido tipada é o que permite calcular ritmo
--
-- Duas decisões aqui, e as duas são de negócio, não de código.
--
-- Rode com:
--   python3 scripts/run_sql.py aulas/aula-02-engenharia-de-dados/exemplo-02-silver-pedidos.sql

CREATE OR REPLACE TABLE rota_perfume.silver.pedidos AS
SELECT
    CAST(pedido_id AS INT)                                  AS pedido_id,
    CAST(cliente_id AS INT)                                 AS cliente_id,
    CAST(vendedor_id AS INT)                                AS vendedor_id,

    -- 12% das datas vêm como dd/MM/aaaa. Uma coluna só, dois formatos.
    coalesce(try_to_date(data_pedido, 'yyyy-MM-dd'),
             try_to_date(data_pedido, 'dd/MM/yyyy'))        AS data_pedido,

    canal,
    status,

    -- Decisão 1: a flag vem do STATUS, não do valor zerado. Confiar no
    -- valor seria frágil — um pedido legítimo de R$ 0,00 viraria cancelado.
    status = 'Cancelado'                                    AS cancelado,

    CAST(valor_total AS DECIMAL(18,2))                      AS valor_total,

    -- Decisão 2: valor_liquido é o que conta como receita. Assim quem
    -- consome a tabela soma uma coluna e acerta, sem lembrar do filtro.
    CASE WHEN status = 'Cancelado' THEN CAST(0 AS DECIMAL(18,2))
         ELSE CAST(valor_total AS DECIMAL(18,2)) END        AS valor_liquido,

    _ingerido_em, _arquivo_origem
FROM rota_perfume.bronze.pedidos;


-- ----------------------------------------------------------------------------
-- A receita não pode ter mudado. Se mudou, a limpeza comeu dado.
-- ----------------------------------------------------------------------------

SELECT
    (SELECT COUNT(*) FROM rota_perfume.silver.pedidos)                          AS linhas,
    (SELECT COUNT(*) FROM rota_perfume.silver.pedidos WHERE data_pedido IS NULL) AS datas_perdidas,
    (SELECT COUNT(*) FROM rota_perfume.silver.pedidos WHERE cancelado)          AS cancelados,
    (SELECT ROUND(SUM(valor_liquido), 2) FROM rota_perfume.silver.pedidos)      AS receita_silver,
    102303828.05                                                                AS receita_esperada;
