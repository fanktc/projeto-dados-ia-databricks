-- ============================================
-- EXEMPLO 04: Features do cliente — a parte que mais vale dinheiro
-- ============================================
-- Conceito: janela temporal, prevenção de vazamento, RFM + sinais de CRM
-- Pergunta de negócio: o que descreve um cliente que está prestes a comprar?
-- Conexão com o exemplo 05: é esta tabela que entra no modelo
--
-- ⚠️ A REGRA QUE NÃO PODE SER QUEBRADA: toda feature só pode usar dado
-- ANTERIOR à data de referência. O alvo olha para os 30 dias DEPOIS.
--
-- Se uma feature enxergar o futuro — por exemplo "total de pedidos" contando
-- o mês do alvo — o modelo acerta 99% no treino e erra tudo em produção.
-- Chama-se vazamento, e é o erro mais comum e mais caro em ciência de dados.
--
-- Aqui a data de referência é 2026-07-31: features com o passado, alvo em
-- agosto. Assim dá para comparar com a régua do exemplo 01, que foi medida
-- exatamente na mesma janela.
--
-- Rode com:
--   python3 scripts/run_sql.py aulas/aula-03-ciencia-de-dados-e-agentes/exemplo-04-features-cliente.sql

CREATE OR REPLACE TABLE lakehouse_rotaperfume.gold.features_cliente AS
WITH parametros AS (
    SELECT DATE'2026-07-31' AS referencia, 30 AS horizonte_dias
),
-- ── só o passado ────────────────────────────────────────────────────────────
passado AS (
    SELECT p.* FROM lakehouse_rotaperfume.silver.pedidos p, parametros
    WHERE NOT p.cancelado AND p.data_pedido <= parametros.referencia
),
rfm AS (
    SELECT
        pa.cliente_id,
        -- R de recência
        datediff((SELECT referencia FROM parametros), MAX(pa.data_pedido)) AS recencia_dias,
        -- F de frequência
        COUNT(*)                                            AS frequencia,
        COUNT(*) FILTER (WHERE pa.data_pedido >=
            date_sub((SELECT referencia FROM parametros), 90))  AS pedidos_90d,
        -- M de monetário
        SUM(pa.valor_liquido)                               AS valor_total,
        AVG(pa.valor_liquido)                               AS ticket_medio,
        stddev_pop(pa.valor_liquido)                        AS ticket_desvio,
        MIN(pa.data_pedido)                                 AS primeira_compra,
        MAX(pa.data_pedido)                                 AS ultima_compra,
        datediff(MAX(pa.data_pedido), MIN(pa.data_pedido))  AS dias_de_relacionamento
    FROM passado pa GROUP BY pa.cliente_id
),
ritmo AS (
    SELECT cliente_id,
           median(datediff(data_pedido, anterior))          AS ritmo_dias,
           stddev_pop(datediff(data_pedido, anterior))      AS ritmo_desvio
    FROM (SELECT cliente_id, data_pedido,
                 lag(data_pedido) OVER (PARTITION BY cliente_id ORDER BY data_pedido) AS anterior
          FROM passado)
    WHERE anterior IS NOT NULL
    GROUP BY cliente_id
),
-- ── sinais que o ERP não enxerga ────────────────────────────────────────────
crm AS (
    SELECT
        v.cliente_id,
        COUNT(*) FILTER (WHERE v.data_visita >=
            date_sub((SELECT referencia FROM parametros), 90))  AS visitas_90d,
        ROUND(AVG(CASE WHEN v.converteu THEN 1.0 ELSE 0.0 END), 3) AS taxa_conversao_visita,
        datediff((SELECT referencia FROM parametros), MAX(v.data_visita)) AS dias_ultima_visita
    FROM lakehouse_rotaperfume.silver.visitas v, parametros
    WHERE v.data_visita <= parametros.referencia
    GROUP BY v.cliente_id
),
funil AS (
    SELECT o.cliente_id,
           COUNT(*) FILTER (WHERE o.aberta)                 AS oport_abertas,
           SUM(o.valor_estimado) FILTER (WHERE o.aberta)    AS valor_no_funil,
           ROUND(AVG(CASE WHEN o.ganha THEN 1.0 ELSE 0.0 END), 3) AS taxa_ganho_historica
    FROM lakehouse_rotaperfume.silver.oportunidades o, parametros
    WHERE o.data_abertura <= parametros.referencia
    GROUP BY o.cliente_id
),
mix AS (
    SELECT f.cliente_id,
           COUNT(DISTINCT f.categoria)                      AS categorias_compradas,
           COUNT(DISTINCT f.marca)                          AS marcas_compradas,
           ROUND(SUM(f.margem) / NULLIF(SUM(f.receita), 0), 3) AS margem_media
    FROM lakehouse_rotaperfume.gold.fato_vendas f, parametros
    WHERE f.data_pedido <= parametros.referencia
    GROUP BY f.cliente_id
),
-- ── o alvo: olha para a frente, e SÓ ele pode ───────────────────────────────
alvo AS (
    SELECT DISTINCT p.cliente_id
    FROM lakehouse_rotaperfume.silver.pedidos p, parametros
    WHERE NOT p.cancelado
      AND p.data_pedido >  parametros.referencia
      AND p.data_pedido <= date_add(parametros.referencia, parametros.horizonte_dias)
)
SELECT
    (SELECT referencia FROM parametros)                     AS data_referencia,
    r.cliente_id,
    c.segmento, c.uf,
    -- RFM
    r.recencia_dias, r.frequencia, r.pedidos_90d,
    ROUND(r.valor_total, 2)                                 AS valor_total,
    ROUND(r.ticket_medio, 2)                                AS ticket_medio,
    ROUND(coalesce(r.ticket_desvio, 0), 2)                  AS ticket_desvio,
    r.dias_de_relacionamento,
    -- ritmo: a feature mais forte, e a mesma que a régua do exemplo 01 usa
    rt.ritmo_dias,
    ROUND(coalesce(rt.ritmo_desvio, 0), 1)                  AS ritmo_desvio,
    ROUND(r.recencia_dias / NULLIF(rt.ritmo_dias, 0), 2)    AS atraso_relativo,
    -- CRM
    coalesce(cr.visitas_90d, 0)                             AS visitas_90d,
    coalesce(cr.taxa_conversao_visita, 0)                   AS taxa_conversao_visita,
    coalesce(cr.dias_ultima_visita, 999)                    AS dias_ultima_visita,
    coalesce(fu.oport_abertas, 0)                           AS oport_abertas,
    ROUND(coalesce(fu.valor_no_funil, 0), 2)                AS valor_no_funil,
    coalesce(fu.taxa_ganho_historica, 0)                    AS taxa_ganho_historica,
    -- mix
    coalesce(mx.categorias_compradas, 0)                    AS categorias_compradas,
    coalesce(mx.marcas_compradas, 0)                        AS marcas_compradas,
    coalesce(mx.margem_media, 0)                            AS margem_media,
    -- ALVO
    CASE WHEN a.cliente_id IS NOT NULL THEN 1 ELSE 0 END    AS comprou_em_30d
FROM rfm r
LEFT JOIN ritmo rt ON rt.cliente_id = r.cliente_id
LEFT JOIN crm   cr ON cr.cliente_id = r.cliente_id
LEFT JOIN funil fu ON fu.cliente_id = r.cliente_id
LEFT JOIN mix   mx ON mx.cliente_id = r.cliente_id
LEFT JOIN alvo  a  ON a.cliente_id  = r.cliente_id
JOIN lakehouse_rotaperfume.gold.dim_cliente c ON c.cliente_id = r.cliente_id
WHERE r.frequencia >= 3;


-- ----------------------------------------------------------------------------
-- O alvo está equilibrado? Se quase todo mundo comprar, não há o que aprender.
-- ----------------------------------------------------------------------------

SELECT
    COUNT(*)                                                AS clientes,
    SUM(comprou_em_30d)                                     AS compraram,
    ROUND(100.0 * AVG(comprou_em_30d), 1)                   AS taxa_do_alvo_pct,
    ROUND(AVG(recencia_dias), 1)                            AS recencia_media,
    ROUND(AVG(ritmo_dias), 1)                               AS ritmo_medio,
    COUNT(*) FILTER (WHERE ritmo_dias IS NULL)              AS sem_ritmo
FROM lakehouse_rotaperfume.gold.features_cliente;
