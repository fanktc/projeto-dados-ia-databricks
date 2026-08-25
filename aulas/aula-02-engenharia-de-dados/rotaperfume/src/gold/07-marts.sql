-- Gold · data marts, um por diretoria
--
-- O ERRO CLÁSSICO é criar um fato por área: fato_vendas_comercial e
-- fato_vendas_produto. Em três meses eles divergem, ninguém sabe qual está
-- certo, e a empresa passa a ter duas verdades.
--
-- O que separa um mart do outro NÃO é a tabela base — é a DIMENSÃO DOMINANTE
-- e as MÉTRICAS. Os três aqui leem o mesmo fato_vendas, e os três somam o
-- mesmo R$ 102.303.828,05. É isso que "conformado" significa.
--
--   Diretoria     Pergunta que só ela faz              Coluna que só ela usa
--   ───────────────────────────────────────────────────────────────────────
--   Vendas        qual vendedor está abaixo da meta?   meta_mensal
--   Produto       vendo o dobro e ganho menos?         custo_unitario
--   Financeiro    quanto entra em caixa em 30 dias?    data_vencimento

CREATE OR REPLACE TABLE lakehouse_rotaperfume.gold.mart_vendas_por_vendedor
COMMENT 'Mart da diretoria de Vendas. Grão: vendedor × mês. Responde meta, produtividade e cobertura de carteira.'
AS
SELECT
    f.vendedor_id,
    v.nome        AS vendedor,
    v.regiao,
    f.ano, f.mes,
    v.meta_mensal,
    ROUND(SUM(f.receita), 2)                       AS receita,
    ROUND(SUM(f.margem), 2)                        AS margem,
    ROUND(SUM(f.receita) / nullif(v.meta_mensal, 0), 4) AS atingimento_meta,
    COUNT(DISTINCT f.pedido_id)                    AS pedidos,
    COUNT(DISTINCT f.cliente_id)                   AS clientes_atendidos,
    ROUND(SUM(f.receita) / nullif(COUNT(DISTINCT f.pedido_id), 0), 2) AS ticket_medio,
    v.clientes_na_carteira
FROM lakehouse_rotaperfume.gold.fato_vendas f
JOIN lakehouse_rotaperfume.gold.dim_vendedor v ON v.vendedor_id = f.vendedor_id
GROUP BY f.vendedor_id, v.nome, v.regiao, f.ano, f.mes, v.meta_mensal, v.clientes_na_carteira;

CREATE OR REPLACE TABLE lakehouse_rotaperfume.gold.mart_produto_performance
COMMENT 'Mart da diretoria de Produto. Grão: SKU × mês, com curva ABC calculada sobre o período inteiro.'
AS
WITH por_sku AS (
  SELECT sku, SUM(receita) AS receita_total
  FROM lakehouse_rotaperfume.gold.fato_vendas
  GROUP BY sku
),
-- Curva ABC: ordena por receita e acumula. A é o que faz 80% do faturamento,
-- B vai até 95%, C é a cauda. É a conta mais simples que muda decisão de mix.
abc AS (
  SELECT sku,
         SUM(receita_total) OVER (ORDER BY receita_total DESC
                                  ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW)
         / SUM(receita_total) OVER () AS acumulado_pct
  FROM por_sku
)
SELECT
    f.sku,
    p.descricao, p.marca, p.categoria, p.nota_olfativa,
    f.ano, f.mes,
    SUM(abs(f.quantidade))                         AS pecas,
    ROUND(SUM(f.receita), 2)                       AS receita,
    ROUND(SUM(f.margem), 2)                        AS margem,
    ROUND(SUM(f.margem) / nullif(SUM(f.receita), 0), 4) AS margem_pct,
    p.margem_tabela_pct,
    ROUND(SUM(CASE WHEN f.devolucao THEN abs(f.receita) ELSE 0 END), 2) AS receita_devolvida,
    CASE WHEN MAX(a.acumulado_pct) <= 0.80 THEN 'A'
         WHEN MAX(a.acumulado_pct) <= 0.95 THEN 'B'
         ELSE 'C' END                              AS curva_abc,
    p.descontinuado
FROM lakehouse_rotaperfume.gold.fato_vendas f
JOIN lakehouse_rotaperfume.gold.dim_produto p ON p.sku = f.sku
JOIN abc a ON a.sku = f.sku
GROUP BY f.sku, p.descricao, p.marca, p.categoria, p.nota_olfativa,
         f.ano, f.mes, p.margem_tabela_pct, p.descontinuado;

CREATE OR REPLACE TABLE lakehouse_rotaperfume.gold.mart_financeiro_recebimento
COMMENT 'Mart da diretoria Financeira. Grão: mês de vencimento × forma de pagamento. Responde caixa, atraso e custo de taxa.'
AS
SELECT
    year(pg.data_vencimento)  AS ano_vencimento,
    month(pg.data_vencimento) AS mes_vencimento,
    pg.forma_pagamento,
    COUNT(*)                                    AS titulos,
    ROUND(SUM(pg.valor), 2)                     AS valor_a_receber,
    ROUND(SUM(CASE WHEN pg.recebido THEN pg.valor ELSE 0 END), 2) AS valor_recebido,
    ROUND(SUM(pg.valor - pg.valor_liquido), 2)  AS custo_de_taxa,
    ROUND(AVG(pg.taxa_pct), 4)                  AS taxa_media_pct,
    ROUND(AVG(CASE WHEN pg.dias_de_atraso > 0 THEN pg.dias_de_atraso END), 1) AS atraso_medio_dias,
    SUM(CASE WHEN pg.dias_de_atraso > 0 THEN 1 ELSE 0 END) AS titulos_em_atraso
FROM lakehouse_rotaperfume.silver.pagamentos pg
JOIN lakehouse_rotaperfume.silver.pedidos p ON p.pedido_id = pg.pedido_id AND NOT p.cancelado
WHERE pg.data_vencimento IS NOT NULL
GROUP BY 1, 2, 3;

ALTER TABLE lakehouse_rotaperfume.gold.mart_vendas_por_vendedor ALTER COLUMN atingimento_meta
  COMMENT 'Receita do vendedor no mês dividida pela meta mensal. 1,0 é exatamente a meta.';
ALTER TABLE lakehouse_rotaperfume.gold.mart_produto_performance ALTER COLUMN curva_abc
  COMMENT 'A: SKUs que somam os primeiros 80% da receita do período. B: até 95%. C: a cauda.';
ALTER TABLE lakehouse_rotaperfume.gold.mart_financeiro_recebimento ALTER COLUMN custo_de_taxa
  COMMENT 'Diferença entre o valor do título e o valor líquido creditado. É o que a maquininha e o meio de pagamento levam.';
