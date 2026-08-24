-- ============================================
-- EXEMPLO 07: Testes que quebram antes do dashboard
-- ============================================
-- Conceito: assertivas sobre o resultado, não sobre o código
-- Pergunta de negócio: dá para confiar nesse número antes de mandar pro gestor?
-- Conexão com a aula 04: estes testes viram tarefa do job agendado
--
-- Teste de pipeline não é teste de software. Ninguém está verificando se a
-- função soma direito — está verificando se o NÚMERO que vai para a tela do
-- diretor continua sendo o número certo depois da carga de hoje.
--
-- O mais importante é o primeiro: limpeza não pode mudar o faturamento.
--
-- Rode com:
--   python3 scripts/run_sql.py aulas/aula-02-engenharia-de-dados/exemplo-07-testes-de-qualidade.sql

SELECT * FROM (
    -- ── 1. O teste que importa mais que todos os outros ────────────────
    SELECT 1 AS n, 'receita preservada da bronze até a gold' AS teste,
           CAST((SELECT ROUND(SUM(receita),2) FROM lakehouse_rotaperfume.gold.fato_vendas) AS STRING) AS obtido,
           '102303828.05' AS esperado,
           (SELECT ROUND(SUM(receita),2) FROM lakehouse_rotaperfume.gold.fato_vendas) = 102303828.05 AS passou

    -- ── 2. Deduplicação funcionou ───────────────────────────────────────
    UNION ALL SELECT 2, 'CNPJ único na silver',
           CAST((SELECT COUNT(*) FROM (SELECT cnpj FROM lakehouse_rotaperfume.silver.clientes
                                       GROUP BY cnpj HAVING COUNT(*) > 1)) AS STRING),
           '0',
           (SELECT COUNT(*) FROM (SELECT cnpj FROM lakehouse_rotaperfume.silver.clientes
                                  GROUP BY cnpj HAVING COUNT(*) > 1)) = 0

    -- ── 3. Nenhuma data se perdeu na conversão ──────────────────────────
    UNION ALL SELECT 3, 'nenhuma data nula em pedidos',
           CAST((SELECT COUNT(*) FROM lakehouse_rotaperfume.silver.pedidos WHERE data_pedido IS NULL) AS STRING),
           '0',
           (SELECT COUNT(*) FROM lakehouse_rotaperfume.silver.pedidos WHERE data_pedido IS NULL) = 0

    -- ── 4. Receita negativa só pode existir em devolução ────────────────
    UNION ALL SELECT 4, 'receita negativa apenas em devolução',
           CAST((SELECT COUNT(*) FROM lakehouse_rotaperfume.gold.fato_vendas
                 WHERE receita < 0 AND NOT devolucao) AS STRING),
           '0',
           (SELECT COUNT(*) FROM lakehouse_rotaperfume.gold.fato_vendas
            WHERE receita < 0 AND NOT devolucao) = 0

    -- ── 5. Volume dentro do esperado: pega queda silenciosa de ingestão ──
    UNION ALL SELECT 5, 'volume da fato_vendas entre 150k e 260k',
           CAST((SELECT COUNT(*) FROM lakehouse_rotaperfume.gold.fato_vendas) AS STRING),
           '150000 a 260000',
           (SELECT COUNT(*) FROM lakehouse_rotaperfume.gold.fato_vendas) BETWEEN 150000 AND 260000

    -- ── 6. Integridade referencial: todo pedido do fato existe na silver ─
    UNION ALL SELECT 6, 'nenhum pedido órfão no fato',
           CAST((SELECT COUNT(*) FROM (
                   SELECT DISTINCT f.pedido_id FROM lakehouse_rotaperfume.gold.fato_vendas f
                   LEFT ANTI JOIN lakehouse_rotaperfume.silver.pedidos p ON p.pedido_id = f.pedido_id
                 )) AS STRING),
           '0',
           (SELECT COUNT(*) FROM (
              SELECT DISTINCT f.pedido_id FROM lakehouse_rotaperfume.gold.fato_vendas f
              LEFT ANTI JOIN lakehouse_rotaperfume.silver.pedidos p ON p.pedido_id = f.pedido_id
            )) = 0

    -- ── 7. Todo cliente do fato existe na dimensão ──────────────────────
    UNION ALL SELECT 7, 'nenhum cliente órfão no fato',
           CAST((SELECT COUNT(DISTINCT f.cliente_id) FROM lakehouse_rotaperfume.gold.fato_vendas f
                 LEFT ANTI JOIN lakehouse_rotaperfume.gold.dim_cliente c ON c.cliente_id = f.cliente_id) AS STRING),
           '0',
           (SELECT COUNT(DISTINCT f.cliente_id) FROM lakehouse_rotaperfume.gold.fato_vendas f
            LEFT ANTI JOIN lakehouse_rotaperfume.gold.dim_cliente c ON c.cliente_id = f.cliente_id) = 0

    -- ── 8. Os marts não podem divergir da fonte ─────────────────────────
    UNION ALL SELECT 8, 'mart de produto bate com o fato',
           CAST((SELECT ROUND(SUM(receita),2) FROM lakehouse_rotaperfume.gold.mart_produto_performance) AS STRING),
           '102303828.05',
           (SELECT ROUND(SUM(receita),2) FROM lakehouse_rotaperfume.gold.mart_produto_performance) = 102303828.05

    -- ── 9. CNPJ com 14 dígitos, zeros à esquerda preservados ────────────
    UNION ALL SELECT 9, 'todo CNPJ com 14 dígitos',
           CAST((SELECT COUNT(*) FROM lakehouse_rotaperfume.silver.clientes WHERE length(cnpj) <> 14) AS STRING),
           '0',
           (SELECT COUNT(*) FROM lakehouse_rotaperfume.silver.clientes WHERE length(cnpj) <> 14) = 0
) ORDER BY n;
