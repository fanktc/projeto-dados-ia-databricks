-- ============================================
-- EXEMPLO 06: Data marts — um por diretoria
-- ============================================
-- Conceito: view sobre fato conformado, grão por área, métrica governada
-- Pergunta de negócio: cada diretoria enxerga o que precisa, sem números divergentes
-- Conexão com a aula 04: são estas views que o dashboard e o Genie leem
--
-- O ERRO CLÁSSICO é criar um FATO por diretoria: fato_vendas_comercial e
-- fato_vendas_produto. Em três meses eles divergem e ninguém sabe qual está
-- certo.
--
-- O que separa um mart do outro é a DIMENSÃO DOMINANTE e as MÉTRICAS —
-- não a tabela base. Os três abaixo leem o mesmo fato_vendas.
--
-- Rode com:
--   python3 scripts/run_sql.py aulas/aula-02-engenharia-de-dados/exemplo-06-data-marts-por-diretoria.sql

-- ═══════════════════════════════════════════════════════════════════
-- MART 1 · VENDAS — dimensão dominante: vendedor e cliente
-- "Qual vendedor está abaixo da meta? Onde o funil vaza?"
-- ═══════════════════════════════════════════════════════════════════

CREATE OR REPLACE VIEW rota_perfume.gold.mart_vendas_por_vendedor AS
SELECT
    v.vendedor_id,
    v.nome                                              AS vendedor,
    v.regiao,
    v.ativo                                             AS vendedor_ativo,
    v.meta_mensal,
    v.clientes_na_carteira,
    f.ano_mes,
    COUNT(DISTINCT f.pedido_id)                         AS pedidos,
    COUNT(DISTINCT f.cliente_id)                        AS clientes_atendidos,
    ROUND(SUM(f.receita), 2)                            AS receita,
    ROUND(SUM(f.margem), 2)                             AS margem,
    -- o número que a reunião de comercial quer ver
    ROUND(100 * SUM(f.receita) / v.meta_mensal, 1)      AS pct_da_meta
FROM rota_perfume.gold.fato_vendas f
JOIN rota_perfume.gold.dim_vendedor v ON v.vendedor_id = f.vendedor_id
GROUP BY v.vendedor_id, v.nome, v.regiao, v.ativo, v.meta_mensal,
         v.clientes_na_carteira, f.ano_mes;


CREATE OR REPLACE VIEW rota_perfume.gold.mart_vendas_funil AS
SELECT
    o.origem,
    o.etapa,
    COUNT(*)                                            AS oportunidades,
    ROUND(SUM(o.valor_estimado), 2)                     AS valor_estimado,
    ROUND(AVG(o.ciclo_dias), 1)                         AS ciclo_medio_dias,
    ROUND(100.0 * COUNT(*) FILTER (WHERE o.ganha)
              / NULLIF(COUNT(*) FILTER (WHERE NOT o.aberta), 0), 1) AS taxa_conversao_pct
FROM rota_perfume.silver.oportunidades o
GROUP BY o.origem, o.etapa;


-- ═══════════════════════════════════════════════════════════════════
-- MART 2 · PRODUTO — dimensão dominante: SKU, marca, categoria
-- "Kit Presente vende o dobro e dá 17 pontos menos de margem. Mudo o mix?"
-- Repare: esta é a única área que olha custo_unitario.
-- ═══════════════════════════════════════════════════════════════════

CREATE OR REPLACE VIEW rota_perfume.gold.mart_produto_performance AS
SELECT
    p.sku,
    p.descricao,
    p.categoria,
    p.marca,
    p.nota_olfativa,
    p.lancamento                                        AS e_lancamento,
    p.ativo                                             AS sku_ativo,
    SUM(f.quantidade)                                   AS unidades,
    ROUND(SUM(f.receita), 2)                            AS receita,
    ROUND(SUM(f.margem), 2)                             AS margem,
    ROUND(100 * SUM(f.margem) / NULLIF(SUM(f.receita), 0), 1) AS margem_pct,
    -- participação na receita total: a curva ABC sai daqui
    ROUND(100 * SUM(f.receita) / SUM(SUM(f.receita)) OVER (), 2) AS pct_da_receita,
    ROUND(SUM(f.receita) FILTER (WHERE f.devolucao), 2) AS devolvido
FROM rota_perfume.gold.fato_vendas f
JOIN rota_perfume.gold.dim_produto p ON p.sku = f.sku
GROUP BY p.sku, p.descricao, p.categoria, p.marca, p.nota_olfativa,
         p.lancamento, p.ativo;


-- ═══════════════════════════════════════════════════════════════════
-- MART 3 · FINANCEIRO — dimensão dominante: forma de pagamento e vencimento
-- "Quanto entra em caixa nos próximos 30 dias? Quanto o cartão custa?"
-- Esta é a única área que olha data_vencimento e taxa.
-- ═══════════════════════════════════════════════════════════════════

CREATE OR REPLACE VIEW rota_perfume.gold.mart_financeiro_recebimento AS
SELECT
    pg.forma_pagamento,
    date_format(pg.data_vencimento, 'yyyy-MM')          AS vencimento_mes,
    pg.status_pagamento,
    COUNT(*)                                            AS titulos,
    ROUND(SUM(pg.valor), 2)                             AS valor_bruto,
    ROUND(SUM(pg.valor_liquido), 2)                     AS valor_liquido,
    -- o que a operadora fica: some no fluxo e não aparece no ERP
    ROUND(SUM(pg.custo_financeiro), 2)                  AS custo_financeiro,
    ROUND(AVG(pg.taxa_pct), 2)                          AS taxa_media_pct,
    ROUND(AVG(pg.dias_de_atraso), 1)                    AS atraso_medio_dias,
    COUNT(*) FILTER (WHERE pg.em_aberto)                AS em_aberto
FROM rota_perfume.silver.pagamentos pg
GROUP BY pg.forma_pagamento, date_format(pg.data_vencimento, 'yyyy-MM'),
         pg.status_pagamento;


-- ----------------------------------------------------------------------------
-- As três diretorias, e o mesmo faturamento em todas.
-- ----------------------------------------------------------------------------

SELECT 'vendas · receita somada por vendedor' AS visao,
       ROUND(SUM(receita), 2)                 AS receita
FROM rota_perfume.gold.mart_vendas_por_vendedor
UNION ALL
SELECT 'produto · receita somada por SKU',
       ROUND(SUM(receita), 2)
FROM rota_perfume.gold.mart_produto_performance
UNION ALL
SELECT 'a fonte única · gold.fato_vendas',
       ROUND(SUM(receita), 2)
FROM rota_perfume.gold.fato_vendas;
