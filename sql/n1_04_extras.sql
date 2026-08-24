-- Noite 1 · O que mais o dado responde
--
-- Rode com: python3 scripts/run_sql.py sql/n1_04_extras.sql

-- ============================================================================
-- A. Sazonalidade: em que mês do ano a distribuidora vende mais?
--
-- Duas armadilhas nesta query, e as duas valem parar para explicar:
--
-- 1. Setembro/2024 é o primeiro mês da série e tem 2.068 pedidos contra ~1.100
--    dos meses seguintes. Isso não é sazonalidade, é o começo da base: todo
--    cliente entra com uma primeira compra.
-- 2. A série tem 24 meses, mas não são 2 anos redondos (vai de set/2024 a
--    ago/2026). Somar por mês-do-ano sem cuidado faz um mês que aparece duas
--    vezes ganhar de um que aparece uma só — e o ranking vira artefato de
--    calendário, não comportamento de compra.
--
-- Por isso a janela abaixo é de 12 meses fechados: nov/2024 a out/2025.
-- Cada mês entra exatamente uma vez.
--
-- O insight que a turma não espera: o pico NÃO é dezembro. O varejo compra
-- ANTES da data comemorativa, então o pico da distribuidora é o mês anterior:
--   abril   -> reposição para o Dia das Mães
--   junho   -> Dia dos Namorados
--   outubro -> reposição para a Black Friday
-- Dezembro e janeiro são vale: o varejo já está abastecido.
-- ============================================================================

SELECT
    month(coalesce(try_to_date(data_pedido, 'yyyy-MM-dd'),
                   try_to_date(data_pedido, 'dd/MM/yyyy'))) AS mes_do_ano,
    COUNT(*)                                                AS pedidos,
    ROUND(SUM(CAST(valor_total AS DECIMAL(18,2))), 2)       AS receita
FROM rota_perfume.bronze.pedidos
WHERE status <> 'Cancelado'
  AND coalesce(try_to_date(data_pedido, 'yyyy-MM-dd'),
               try_to_date(data_pedido, 'dd/MM/yyyy'))
      BETWEEN DATE'2024-11-01' AND DATE'2025-10-31'
GROUP BY 1
ORDER BY receita DESC;

-- ============================================================================
-- B. Curva ABC de marca: a receita concentra em poucas marcas?
--
-- Aqui aparece o primeiro join de verdade: item -> produto.
-- E a primeira decisão de negócio: excluir devolução. Quantidade negativa é
-- mercadoria que voltou; somar isso na receita de marca distorce a leitura.
-- ============================================================================

SELECT
    pr.marca,
    COUNT(DISTINCT i.pedido_id)                          AS pedidos,
    ROUND(SUM(CAST(i.valor_bruto AS DECIMAL(18,2))), 2)  AS receita,
    ROUND(100 * SUM(CAST(i.valor_bruto AS DECIMAL(18,2)))
              / SUM(SUM(CAST(i.valor_bruto AS DECIMAL(18,2)))) OVER (), 1) AS pct
FROM rota_perfume.bronze.itens_pedido i
JOIN rota_perfume.bronze.produtos pr ON pr.sku = i.sku
JOIN rota_perfume.bronze.pedidos  p  ON p.pedido_id = i.pedido_id
WHERE p.status <> 'Cancelado'
  AND CAST(i.quantidade AS INT) > 0        -- fora devolução
GROUP BY 1
ORDER BY receita DESC;

-- ============================================================================
-- C. Margem por categoria: vender mais é ganhar mais?
--
-- Não. Kit Presente vende quase o dobro de Óleo Concentrado e entrega
-- 17 pontos percentuais menos de margem. É a análise que muda a conversa
-- com o comercial: a meta não deveria ser só faturamento.
-- ============================================================================

SELECT
    pr.categoria,
    ROUND(SUM(CAST(i.valor_bruto AS DECIMAL(18,2))), 2)  AS receita,
    ROUND(SUM(CAST(i.quantidade AS INT)
              * CAST(pr.custo_unitario AS DECIMAL(18,2))), 2) AS custo,
    ROUND(100 * (SUM(CAST(i.valor_bruto AS DECIMAL(18,2)))
                 - SUM(CAST(i.quantidade AS INT) * CAST(pr.custo_unitario AS DECIMAL(18,2))))
              / SUM(CAST(i.valor_bruto AS DECIMAL(18,2))), 1) AS margem_pct
FROM rota_perfume.bronze.itens_pedido i
JOIN rota_perfume.bronze.produtos pr ON pr.sku = i.sku
JOIN rota_perfume.bronze.pedidos  p  ON p.pedido_id = i.pedido_id
WHERE p.status <> 'Cancelado'
  AND CAST(i.quantidade AS INT) > 0
GROUP BY 1
ORDER BY margem_pct DESC;

-- ============================================================================
-- D. Efeito de lançamento: produto novo puxa receita?
--
-- 47 dos 292 SKUs têm data de lançamento no período. São 16% dos produtos.
-- Veja quanto eles representam da receita.
-- ============================================================================

SELECT
    CASE WHEN pr.data_lancamento IS NULL THEN 'catálogo antigo'
         ELSE 'lançado no período' END                   AS tipo,
    COUNT(DISTINCT pr.sku)                               AS skus,
    ROUND(SUM(CAST(i.valor_bruto AS DECIMAL(18,2))), 2)  AS receita,
    ROUND(100 * SUM(CAST(i.valor_bruto AS DECIMAL(18,2)))
              / SUM(SUM(CAST(i.valor_bruto AS DECIMAL(18,2)))) OVER (), 1) AS pct_receita
FROM rota_perfume.bronze.itens_pedido i
JOIN rota_perfume.bronze.produtos pr ON pr.sku = i.sku
JOIN rota_perfume.bronze.pedidos  p  ON p.pedido_id = i.pedido_id
WHERE p.status <> 'Cancelado'
  AND CAST(i.quantidade AS INT) > 0
GROUP BY 1;

-- ============================================================================
-- E. O gancho da noite 2: a conta que NÃO fecha.
--
-- Pedido cancelado tem valor_total zerado, mas os itens dele continuam
-- gravados com o valor cheio. Ou seja: existe dinheiro nos itens que o
-- pedido diz que não existe. Ninguém "consertou" isso ainda.
--
-- É esse tipo de buraco que a camada silver resolve amanhã.
-- ============================================================================

SELECT
    COUNT(DISTINCT i.pedido_id)                          AS pedidos_cancelados,
    COUNT(*)                                             AS itens_orfaos,
    ROUND(SUM(CAST(i.valor_bruto AS DECIMAL(18,2))), 2)  AS valor_que_some
FROM rota_perfume.bronze.itens_pedido i
JOIN rota_perfume.bronze.pedidos p ON p.pedido_id = i.pedido_id
WHERE p.status = 'Cancelado';
