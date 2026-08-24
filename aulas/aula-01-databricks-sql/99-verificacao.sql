-- Noite 1 · Verificação
--
-- O PRD define números-âncora para o dataset. Se uma query der resultado
-- muito diferente destes, o erro está na query, não no dado.
--
-- Cada linha compara o valor calculado com o esperado e diz se bate.
--
-- Rode com: python3 scripts/run_sql.py aulas/aula-01-databricks-sql/99-verificacao.sql

WITH p AS (
  SELECT
      coalesce(try_to_date(data_pedido, 'yyyy-MM-dd'),
               try_to_date(data_pedido, 'dd/MM/yyyy')) AS data_pedido,
      CAST(valor_total AS DECIMAL(18,2))               AS valor_total
  FROM rota_perfume.bronze.pedidos
  WHERE status <> 'Cancelado'
),
m AS (
  SELECT
      ROUND(SUM(valor_total), 2)                          AS receita_total,
      COUNT(*)                                            AS pedidos,
      ROUND(SUM(valor_total) / COUNT(*), 2)               AS ticket_medio,
      ROUND(SUM(CASE WHEN date_trunc('month', data_pedido) = DATE'2025-10-01'
                     THEN valor_total ELSE 0 END), 2)     AS out_2025,
      ROUND(SUM(CASE WHEN date_trunc('month', data_pedido) = DATE'2026-01-01'
                     THEN valor_total ELSE 0 END), 2)     AS jan_2026
  FROM p
)
SELECT 'receita total (24 meses)' AS metrica, CAST(receita_total AS STRING) AS calculado,
       '~102.000.000' AS esperado, receita_total BETWEEN 100e6 AND 104e6 AS bate FROM m
UNION ALL
SELECT 'pedidos faturados', CAST(pedidos AS STRING), '27.772', pedidos = 27772 FROM m
UNION ALL
SELECT 'ticket médio por pedido', CAST(ticket_medio AS STRING), '~3.684',
       ticket_medio BETWEEN 3600 AND 3760 FROM m
UNION ALL
SELECT 'receita outubro/2025', CAST(out_2025 AS STRING), '~7.000.000',
       out_2025 BETWEEN 6.8e6 AND 7.2e6 FROM m
UNION ALL
SELECT 'receita janeiro/2026', CAST(jan_2026 AS STRING), '~2.500.000',
       jan_2026 BETWEEN 2.3e6 AND 2.7e6 FROM m
UNION ALL
SELECT 'datas em dd/MM/yyyy (12%)',
       CAST((SELECT COUNT(*) FROM rota_perfume.bronze.pedidos WHERE data_pedido LIKE '%/%') AS STRING),
       '3.443',
       (SELECT COUNT(*) FROM rota_perfume.bronze.pedidos WHERE data_pedido LIKE '%/%') = 3443
UNION ALL
SELECT 'CNPJ com espaço em volta',
       CAST((SELECT COUNT(*) FROM rota_perfume.bronze.clientes WHERE cnpj <> trim(cnpj)) AS STRING),
       '223',
       (SELECT COUNT(*) FROM rota_perfume.bronze.clientes WHERE cnpj <> trim(cnpj)) = 223
UNION ALL
SELECT 'itens de devolução (qtd negativa)',
       CAST((SELECT COUNT(*) FROM rota_perfume.bronze.itens_pedido WHERE CAST(quantidade AS INT) < 0) AS STRING),
       '2.327',
       (SELECT COUNT(*) FROM rota_perfume.bronze.itens_pedido WHERE CAST(quantidade AS INT) < 0) = 2327
UNION ALL
SELECT 'clientes com CNPJ duplicado',
       CAST((SELECT COUNT(*) FROM (SELECT regexp_replace(trim(cnpj), '[^0-9]', '') c
                                   FROM rota_perfume.bronze.clientes
                                   GROUP BY 1 HAVING COUNT(*) > 1)) AS STRING),
       '40',
       (SELECT COUNT(*) FROM (SELECT regexp_replace(trim(cnpj), '[^0-9]', '') c
                              FROM rota_perfume.bronze.clientes
                              GROUP BY 1 HAVING COUNT(*) > 1)) = 40
UNION ALL
SELECT 'carteiras vigentes com vendedor desligado',
       CAST((SELECT COUNT(*) FROM rota_perfume.bronze.carteira ca
             JOIN rota_perfume.bronze.vendedores v ON v.vendedor_id = ca.vendedor_id
             WHERE ca.data_fim IS NULL AND v.data_desligamento IS NOT NULL) AS STRING),
       '> 0 (sujeira nº 9)',
       (SELECT COUNT(*) FROM rota_perfume.bronze.carteira ca
        JOIN rota_perfume.bronze.vendedores v ON v.vendedor_id = ca.vendedor_id
        WHERE ca.data_fim IS NULL AND v.data_desligamento IS NOT NULL) > 0;
