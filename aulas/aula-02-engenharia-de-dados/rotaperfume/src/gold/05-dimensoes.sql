-- Gold · dimensões conformadas
--
-- "Conformada" quer dizer: existe UMA dim_cliente para a empresa inteira. Se
-- vendas e financeiro tiverem cada um a sua, em três meses elas divergem e a
-- reunião vira uma discussão sobre qual sistema está certo — em vez de sobre
-- o que fazer com o número.
--
-- Dimensão responde "quem/o quê/quando". Fato responde "quanto". Se você está
-- em dúvida sobre onde uma coluna mora, pergunte se ela SOMA: se soma, é fato.

CREATE OR REPLACE TABLE lakehouse_rotaperfume.gold.dim_cliente
COMMENT 'Uma linha por cliente, com o resumo do relacionamento comercial. Dimensão conformada: é esta que todo mart usa.'
AS
WITH pedidos_do_cliente AS (
  SELECT cliente_id,
         min(data_pedido)            AS primeiro_pedido,
         max(data_pedido)            AS ultimo_pedido,
         count(*)                    AS total_pedidos,
         sum(valor_liquido)          AS receita_acumulada
  FROM lakehouse_rotaperfume.silver.pedidos
  WHERE NOT cancelado
  GROUP BY cliente_id
)
SELECT
    c.cliente_id, c.cnpj, c.razao_social, c.segmento, c.cidade, c.uf, c.bairro,
    c.data_cadastro, c.ativo,
    p.primeiro_pedido, p.ultimo_pedido,
    coalesce(p.total_pedidos, 0)                       AS total_pedidos,
    coalesce(p.receita_acumulada, 0)                   AS receita_acumulada,
    -- "Dias sem comprar" é a métrica que vira churn na noite 3. A referência é
    -- o último pedido do dataset inteiro, não a data de hoje: o dado é fixo, e
    -- todo aluno precisa chegar no mesmo número.
    datediff((SELECT max(data_pedido) FROM lakehouse_rotaperfume.silver.pedidos), p.ultimo_pedido)
                                                       AS dias_sem_comprar
FROM lakehouse_rotaperfume.silver.clientes c
LEFT JOIN pedidos_do_cliente p ON p.cliente_id = c.cliente_id;

CREATE OR REPLACE TABLE lakehouse_rotaperfume.gold.dim_produto
COMMENT 'Uma linha por SKU, com marca, categoria, nota olfativa, custo e status de linha.'
AS
SELECT
    sku, descricao, categoria, marca, nota_olfativa, unidade,
    preco_tabela, custo_unitario, data_lancamento, ativo, descontinuado,
    -- Margem teórica do catálogo, para comparar com a margem praticada no fato.
    -- Quando as duas divergem muito, o desconto comercial está comendo a linha.
    round((preco_tabela - custo_unitario) / nullif(preco_tabela, 0), 4) AS margem_tabela_pct
FROM lakehouse_rotaperfume.silver.produtos;

CREATE OR REPLACE TABLE lakehouse_rotaperfume.gold.dim_vendedor
COMMENT 'Uma linha por vendedor, com região, meta mensal e situação.'
AS
SELECT
    v.vendedor_id, v.nome, v.regiao, v.uf,
    v.data_admissao, v.data_desligamento, v.meta_mensal, v.ativo,
    (SELECT count(*) FROM lakehouse_rotaperfume.silver.carteira ca
      WHERE ca.vendedor_id = v.vendedor_id AND ca.vigente) AS clientes_na_carteira
FROM lakehouse_rotaperfume.silver.vendedores v;

CREATE OR REPLACE TABLE lakehouse_rotaperfume.gold.dim_calendario
COMMENT 'Um dia por linha nos 24 meses da operação. A coluna mes_pico_setor carrega a regra de sazonalidade da distribuição.'
AS
SELECT
    d              AS data,
    year(d)        AS ano,
    month(d)       AS mes,
    date_format(d, 'MMMM')  AS nome_mes,
    quarter(d)     AS trimestre,
    dayofweek(d)   AS dia_semana_num,
    date_format(d, 'EEEE')  AS dia_semana,
    (dayofweek(d) IN (1, 7)) AS fim_de_semana,
    -- A REGRA QUE NENHUM MODELO ADIVINHA: o pico da distribuidora é o mês
    -- ANTERIOR à data comemorativa, porque o varejo compra antes.
    --   abril   → reposição para o Dia das Mães
    --   junho   → Dia dos Namorados
    --   outubro → reposição para a Black Friday
    -- Dezembro e janeiro são VALE: o varejo já está abastecido. Quem não sabe
    -- disso lê o gráfico ao contrário e acha que dezembro foi um mês ruim.
    (month(d) IN (4, 6, 10)) AS mes_pico_setor,
    (month(d) IN (12, 1))    AS mes_vale_setor
FROM (SELECT explode(sequence(DATE'2024-09-01', DATE'2026-08-31', INTERVAL 1 DAY)) AS d);

ALTER TABLE lakehouse_rotaperfume.gold.dim_cliente ALTER COLUMN dias_sem_comprar
  COMMENT 'Dias entre o último pedido do cliente e o último pedido registrado na base. Acima de 90 o cliente é considerado em risco.';
ALTER TABLE lakehouse_rotaperfume.gold.dim_calendario ALTER COLUMN mes_pico_setor
  COMMENT 'Abril, junho e outubro. O pico da distribuidora é o mês ANTERIOR à data comemorativa, porque o varejo compra antes.';
ALTER TABLE lakehouse_rotaperfume.gold.dim_calendario ALTER COLUMN mes_vale_setor
  COMMENT 'Dezembro e janeiro. Vale esperado do setor, não queda de desempenho: o varejo já está abastecido.';
ALTER TABLE lakehouse_rotaperfume.gold.dim_produto ALTER COLUMN margem_tabela_pct
  COMMENT 'Margem teórica do catálogo: (preço de tabela menos custo) sobre preço de tabela. Compare com a margem praticada no fato para ver o efeito do desconto.';
