-- ============================================
-- EXEMPLO 02: Quem está sumindo?
-- ============================================
-- Conceito: corte relativo vs corte fixo, valor observado vs extrapolado
-- Pergunta de negócio: quem parou de comprar, e quanto custa por trimestre?
-- Conexão: a definição de churn é decisão de negócio, não sai do dado
--
-- Rode com:
--   python3 scripts/run_sql.py aulas/aula-03-ciencia-de-dados-e-agentes/exemplo-02-quem-esta-sumindo-sem-modelo.sql

-- ----------------------------------------------------------------------------
-- 2.1 · A DECISÃO: corte fixo ou corte relativo?
--
-- "Sem comprar há 90 dias" é o corte que todo mundo usa. O problema é que
-- ele trata igual dois clientes diferentes: o que compra toda semana e o que
-- compra de trimestre em trimestre.
--
-- Compare as duas réguas antes de escolher.
-- ----------------------------------------------------------------------------

WITH pedidos AS (
    -- Na noite 1 esta CTE tinha CAST e try_to_date em toda coluna. A silver
    -- pagou esse imposto uma vez, para todo mundo.
    SELECT cliente_id, data_pedido, valor_liquido AS valor_total
    FROM lakehouse_rotaperfume.silver.pedidos
    WHERE NOT cancelado
),
ritmo AS (
    -- O "relógio" de cada cliente: mediana do intervalo entre compras.
    -- Só faz sentido para quem tem 3+ pedidos.
    SELECT
        cliente_id,
        COUNT(*)                                             AS pedidos,
        MAX(data_pedido)                                     AS ultima_compra,
        datediff(DATE'2026-08-31', MAX(data_pedido))         AS dias_parado,
        median(datediff(data_pedido, anterior))              AS ritmo_dias
    FROM (
        SELECT cliente_id, data_pedido,
               lag(data_pedido) OVER (PARTITION BY cliente_id ORDER BY data_pedido) AS anterior
        FROM pedidos
    )
    WHERE anterior IS NOT NULL
    GROUP BY cliente_id
    HAVING COUNT(*) >= 2
)
SELECT
    'corte fixo · 90 dias sem comprar'   AS regua,
    COUNT(*) FILTER (WHERE dias_parado > 90)                       AS clientes,
    ROUND(100 * COUNT(*) FILTER (WHERE dias_parado > 90) / COUNT(*), 1) AS pct
FROM ritmo
UNION ALL
SELECT
    'corte relativo · 2,5x o próprio ritmo',
    COUNT(*) FILTER (WHERE dias_parado > 2.5 * ritmo_dias),
    ROUND(100 * COUNT(*) FILTER (WHERE dias_parado > 2.5 * ritmo_dias) / COUNT(*), 1)
FROM ritmo
UNION ALL
SELECT
    'acusados só pelo corte fixo (estão no ritmo deles)',
    COUNT(*) FILTER (WHERE dias_parado > 90 AND dias_parado <= 2.5 * ritmo_dias),
    ROUND(100 * COUNT(*) FILTER (WHERE dias_parado > 90 AND dias_parado <= 2.5 * ritmo_dias) / COUNT(*), 1)
FROM ritmo;

-- ----------------------------------------------------------------------------
-- 2.2 · A RESPOSTA: a lista que o vendedor recebe amanhã de manhã.
--
-- Três decisões de negócio embutidas aqui, e vale falar cada uma em voz alta:
--
-- 1. Só entra quem tem 3+ pedidos. Com 2 pedidos o "ritmo" é um intervalo
--    só — não é ritmo, é coincidência.
-- 2. O valor em risco é OBSERVADO, não extrapolado: quanto o cliente rendia
--    por trimestre enquanto esteve ativo. Projetar o ritmo para frente produz
--    números maiores que tudo o que o cliente já comprou.
-- 3. Quem está parado há mais de um ano sai da lista de recuperação. Não é
--    risco, já é perda — e misturar os dois faz o vendedor perder o dia.
-- ----------------------------------------------------------------------------

WITH pedidos AS (
    -- Na noite 1 esta CTE tinha CAST e try_to_date em toda coluna. A silver
    -- pagou esse imposto uma vez, para todo mundo.
    SELECT cliente_id, data_pedido, valor_liquido AS valor_total
    FROM lakehouse_rotaperfume.silver.pedidos
    WHERE NOT cancelado
),
base AS (
    SELECT
        cliente_id,
        COUNT(*)                                     AS pedidos,
        SUM(valor_total)                             AS receita_historica,
        MIN(data_pedido)                             AS primeira_compra,
        MAX(data_pedido)                             AS ultima_compra,
        datediff(MAX(data_pedido), MIN(data_pedido)) AS dias_ativo,
        datediff(DATE'2026-08-31', MAX(data_pedido)) AS dias_parado
    FROM pedidos
    GROUP BY cliente_id
    HAVING COUNT(*) >= 3 AND datediff(MAX(data_pedido), MIN(data_pedido)) >= 90
),
ritmo AS (
    SELECT cliente_id, median(datediff(data_pedido, anterior)) AS ritmo_dias
    FROM (
        SELECT cliente_id, data_pedido,
               lag(data_pedido) OVER (PARTITION BY cliente_id ORDER BY data_pedido) AS anterior
        FROM pedidos
    )
    WHERE anterior IS NOT NULL
    GROUP BY cliente_id
)
SELECT
    b.cliente_id,
    c.razao_social                                         AS cliente,
    c.segmento,
    c.cidade,
    b.pedidos,
    r.ritmo_dias                                           AS compra_a_cada,
    b.dias_parado                                          AS parado_ha,
    ROUND(b.dias_parado / r.ritmo_dias, 1)                 AS atraso_relativo,
    -- observado: o que ele rendia por trimestre enquanto comprava
    ROUND(b.receita_historica / (b.dias_ativo / 90.0), 2)  AS rendia_por_trimestre,
    ROUND(b.receita_historica, 2)                          AS receita_historica
FROM base b
JOIN ritmo r ON r.cliente_id = b.cliente_id
JOIN lakehouse_rotaperfume.gold.dim_cliente c ON c.cliente_id = b.cliente_id
WHERE b.dias_parado > 2.5 * r.ritmo_dias
  AND b.dias_parado <= 365          -- ainda dá para trazer de volta
ORDER BY rendia_por_trimestre DESC
LIMIT 15;

-- ----------------------------------------------------------------------------
-- 2.3 · O NÚMERO PARA LEVAR À REUNIÃO.
--
-- Separa o que dá para recuperar do que já foi. São conversas diferentes:
-- uma é ação comercial desta semana, a outra é limpeza de carteira.
-- ----------------------------------------------------------------------------

WITH pedidos AS (
    -- Na noite 1 esta CTE tinha CAST e try_to_date em toda coluna. A silver
    -- pagou esse imposto uma vez, para todo mundo.
    SELECT cliente_id, data_pedido, valor_liquido AS valor_total
    FROM lakehouse_rotaperfume.silver.pedidos
    WHERE NOT cancelado
),
base AS (
    SELECT cliente_id, COUNT(*) AS pedidos, SUM(valor_total) AS receita,
           datediff(MAX(data_pedido), MIN(data_pedido))       AS dias_ativo,
           datediff(DATE'2026-08-31', MAX(data_pedido))       AS dias_parado
    FROM pedidos
    GROUP BY cliente_id
    HAVING COUNT(*) >= 3 AND datediff(MAX(data_pedido), MIN(data_pedido)) >= 90
),
ritmo AS (
    SELECT cliente_id, median(datediff(data_pedido, anterior)) AS ritmo_dias
    FROM (
        SELECT cliente_id, data_pedido,
               lag(data_pedido) OVER (PARTITION BY cliente_id ORDER BY data_pedido) AS anterior
        FROM pedidos
    )
    WHERE anterior IS NOT NULL GROUP BY cliente_id
),
classificado AS (
    SELECT
        b.*,
        b.receita / (b.dias_ativo / 90.0) AS por_trimestre,
        CASE
            WHEN b.dias_parado <= 2.5 * r.ritmo_dias THEN 'no ritmo dele'
            WHEN b.dias_parado <= 365                THEN 'sumindo — dá para recuperar'
            ELSE                                          'perdido — parado há mais de um ano'
        END AS situacao
    FROM base b JOIN ritmo r ON r.cliente_id = b.cliente_id
)
SELECT
    situacao,
    COUNT(*)                                                    AS clientes,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1)          AS pct_da_base,
    ROUND(SUM(por_trimestre), 2)                                AS receita_por_trimestre,
    ROUND(SUM(receita), 2)                                      AS receita_historica
FROM classificado
GROUP BY situacao
ORDER BY receita_por_trimestre DESC;
