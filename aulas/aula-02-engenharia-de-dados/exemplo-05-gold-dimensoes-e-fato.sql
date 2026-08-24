-- ============================================
-- EXEMPLO 05: Gold — dimensões conformadas e o fato de vendas
-- ============================================
-- Conceito: modelo estrela, grão do fato, dimensão conformada
-- Pergunta de negócio: uma tabela que responda receita, margem e mix de uma vez
-- Conexão com a aula 03: é desta tabela que saem as features do modelo
--
-- "Conformada" quer dizer: existe UMA dim_cliente, usada por todas as áreas.
-- Se vendas e financeiro tiverem cada um a sua, os relatórios vão divergir e
-- a reunião vira discussão sobre de quem é o número certo.
--
-- Rode com:
--   python3 scripts/run_sql.py aulas/aula-02-engenharia-de-dados/exemplo-05-gold-dimensoes-e-fato.sql

-- ---------------------------------------------------------------- dimensões

CREATE OR REPLACE TABLE lakehouse_rotaperfume.gold.dim_cliente AS
SELECT
    c.cliente_id, c.cnpj, c.razao_social, c.segmento, c.cidade, c.uf, c.bairro,
    c.data_cadastro, c.ativo,
    -- o vendedor que atende hoje: a carteira tem histórico, aqui queremos o atual
    ca.vendedor_id                                          AS vendedor_atual_id,
    ca.orfa                                                 AS carteira_orfa
FROM lakehouse_rotaperfume.silver.clientes c
LEFT JOIN (
    SELECT cliente_id, vendedor_id, orfa,
           ROW_NUMBER() OVER (PARTITION BY cliente_id ORDER BY data_inicio DESC) AS rn
    FROM lakehouse_rotaperfume.silver.carteira WHERE vigente
) ca ON ca.cliente_id = c.cliente_id AND ca.rn = 1;


CREATE OR REPLACE TABLE lakehouse_rotaperfume.gold.dim_produto AS
SELECT sku, descricao, categoria, marca, nota_olfativa, unidade,
       preco_tabela, custo_unitario, ativo, data_lancamento, lancamento
FROM lakehouse_rotaperfume.silver.produtos;


CREATE OR REPLACE TABLE lakehouse_rotaperfume.gold.dim_vendedor AS
SELECT v.vendedor_id, v.nome, v.regiao, v.uf, v.data_admissao,
       v.data_desligamento, v.ativo, v.meta_mensal,
       (SELECT COUNT(*) FROM lakehouse_rotaperfume.silver.carteira c
        WHERE c.vendedor_id = v.vendedor_id AND c.vigente)  AS clientes_na_carteira
FROM lakehouse_rotaperfume.silver.vendedores v;


-- Calendário: parece bobo, mas é o que evita cada analista escrever a própria
-- regra de "qual mês é pico" dentro da query dele.
CREATE OR REPLACE TABLE lakehouse_rotaperfume.gold.dim_calendario AS
SELECT
    d                                                       AS data,
    year(d)                                                 AS ano,
    month(d)                                                AS mes,
    quarter(d)                                              AS trimestre,
    date_format(d, 'yyyy-MM')                               AS ano_mes,
    dayofweek(d)                                            AS dia_semana,
    dayofweek(d) IN (1, 7)                                  AS fim_de_semana,
    CASE month(d) WHEN 4 THEN 'Dia das Mães'
                  WHEN 6 THEN 'Namorados'
                  WHEN 10 THEN 'Black Friday' END           AS reposicao_para,
    month(d) IN (4, 6, 10)                                  AS mes_de_pico,
    month(d) IN (12, 1)                                     AS mes_de_vale
FROM (SELECT explode(sequence(DATE'2024-09-01', DATE'2026-12-31', INTERVAL 1 DAY)) AS d);


-- ---------------------------------------------------------------- o fato
-- GRÃO: uma linha por item de pedido não cancelado. Essa frase é a decisão
-- mais importante do modelo — tudo depois depende dela.
--
-- A DEVOLUÇÃO FICA DENTRO, com flag e valor negativo. É tentador deixá-la de
-- fora ("receita é o que vendeu"), mas aí a gold passa a mostrar
-- R$ 103,6 mi enquanto a silver mostra R$ 102,3 mi. Um dia alguém compara os
-- dois relatórios e a discussão vira sobre qual sistema está certo.
--
-- Com a devolução dentro:
--   SUM(receita)                          -> R$ 102,3 mi, igual à silver
--   SUM(receita) FILTER (WHERE NOT devolucao) -> R$ 103,6 mi, o bruto vendido
--
-- Quem quer cada número tem como pedir, e os dois reconciliam.

CREATE OR REPLACE TABLE lakehouse_rotaperfume.gold.fato_vendas AS
SELECT
    i.item_id,
    p.pedido_id,
    p.data_pedido,
    year(p.data_pedido)                                     AS ano,
    month(p.data_pedido)                                    AS mes,
    date_format(p.data_pedido, 'yyyy-MM')                   AS ano_mes,
    p.canal,
    p.cliente_id,
    p.vendedor_id,
    i.sku,
    pr.categoria,
    pr.marca,
    pr.lancamento                                           AS produto_de_lancamento,
    i.quantidade,
    i.preco_praticado,
    i.desconto_pct,
    i.valor_bruto                                           AS receita,
    i.quantidade * pr.custo_unitario                        AS custo,
    i.valor_bruto - (i.quantidade * pr.custo_unitario)      AS margem,
    i.devolucao,
    i.sku_descontinuado
FROM lakehouse_rotaperfume.silver.itens_pedido i
JOIN lakehouse_rotaperfume.silver.pedidos  p  ON p.pedido_id = i.pedido_id AND NOT p.cancelado
JOIN lakehouse_rotaperfume.silver.produtos pr ON pr.sku = i.sku;


-- ----------------------------------------------------------------------------
SELECT
    (SELECT COUNT(*) FROM lakehouse_rotaperfume.gold.dim_cliente)                  AS clientes,
    (SELECT COUNT(*) FROM lakehouse_rotaperfume.gold.dim_produto)                  AS produtos,
    (SELECT COUNT(*) FROM lakehouse_rotaperfume.gold.dim_vendedor)                 AS vendedores,
    (SELECT COUNT(*) FROM lakehouse_rotaperfume.gold.fato_vendas)                  AS linhas_do_fato,
    -- este número tem de ser idêntico ao da silver.pedidos
    (SELECT ROUND(SUM(receita), 2) FROM lakehouse_rotaperfume.gold.fato_vendas)    AS receita_liquida,
    (SELECT ROUND(SUM(receita) FILTER (WHERE NOT devolucao), 2)
       FROM lakehouse_rotaperfume.gold.fato_vendas)                                AS receita_bruta,
    (SELECT ROUND(SUM(receita) FILTER (WHERE devolucao), 2)
       FROM lakehouse_rotaperfume.gold.fato_vendas)                                AS devolucoes,
    (SELECT ROUND(100 * SUM(margem) / SUM(receita), 1)
       FROM lakehouse_rotaperfume.gold.fato_vendas)                                AS margem_pct,
    (SELECT ROUND(SUM(valor_liquido), 2) FROM lakehouse_rotaperfume.silver.pedidos) AS confere_com_a_silver;
