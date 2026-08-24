-- ============================================
-- EXEMPLO 03: Silver de itens e produtos — a devolução
-- ============================================
-- Conceito: JOIN para enriquecer, flag em vez de descarte, abs()
-- Pergunta de negócio: o que foi vendido, e o que voltou?
-- Conexão com a aula 03: quantidade_liquida é a base do cálculo de margem
--
-- A devolução vem como quantidade negativa. Tem três saídas, e duas são ruins:
--   jogar a linha fora   -> some receita negativa, o faturamento infla
--   deixar como está     -> toda soma da empresa fica contaminada
--   sinalizar            -> quem quiser somar, soma; quem quiser separar, separa
--
-- Rode com:
--   python3 scripts/run_sql.py aulas/aula-02-engenharia-de-dados/exemplo-03-silver-itens-e-produtos.sql

CREATE OR REPLACE TABLE rota_perfume.silver.produtos AS
SELECT
    sku,
    descricao, categoria, marca, nota_olfativa, unidade,
    CAST(preco_tabela AS DECIMAL(18,2))                     AS preco_tabela,
    CAST(custo_unitario AS DECIMAL(18,2))                   AS custo_unitario,
    ativo = 'S'                                             AS ativo,
    coalesce(try_to_date(data_lancamento, 'yyyy-MM-dd'),
             try_to_date(data_lancamento, 'dd/MM/yyyy'))    AS data_lancamento,
    -- Produto lançado dentro do período tem comportamento próprio de venda
    coalesce(try_to_date(data_lancamento, 'yyyy-MM-dd'),
             try_to_date(data_lancamento, 'dd/MM/yyyy')) IS NOT NULL AS lancamento,
    _ingerido_em, _arquivo_origem
FROM rota_perfume.bronze.produtos;


CREATE OR REPLACE TABLE rota_perfume.silver.itens_pedido AS
SELECT
    CAST(i.item_id AS INT)                                  AS item_id,
    CAST(i.pedido_id AS INT)                                AS pedido_id,
    i.sku,
    CAST(i.quantidade AS INT)                               AS quantidade,
    abs(CAST(i.quantidade AS INT))                          AS quantidade_abs,
    CAST(i.quantidade AS INT) < 0                           AS devolucao,
    CAST(i.preco_praticado AS DECIMAL(18,2))                AS preco_praticado,
    CAST(i.desconto_pct AS DECIMAL(9,2))                    AS desconto_pct,
    CAST(i.valor_bruto AS DECIMAL(18,2))                    AS valor_bruto,
    -- SKU descontinuado que continuou sendo vendido: não é erro de digitação,
    -- é ruptura de processo. Marcar deixa o problema visível para o comercial.
    NOT p.ativo                                             AS sku_descontinuado,
    i._ingerido_em, i._arquivo_origem
FROM rota_perfume.bronze.itens_pedido i
LEFT JOIN rota_perfume.silver.produtos p ON p.sku = i.sku;


-- ----------------------------------------------------------------------------
SELECT
    (SELECT COUNT(*) FROM rota_perfume.silver.produtos)                            AS produtos,
    (SELECT COUNT(*) FROM rota_perfume.silver.produtos WHERE lancamento)           AS lancamentos,
    (SELECT COUNT(*) FROM rota_perfume.silver.itens_pedido)                        AS itens,
    (SELECT COUNT(*) FROM rota_perfume.silver.itens_pedido WHERE devolucao)        AS devolucoes,
    (SELECT COUNT(*) FROM rota_perfume.silver.itens_pedido WHERE sku_descontinuado) AS itens_de_sku_morto;
