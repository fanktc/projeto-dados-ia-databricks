-- Silver · itens de pedido e produtos
--
-- A DECISÃO DA NOITE está aqui. Quantidade negativa em itens_pedido não é erro
-- de digitação: é DEVOLUÇÃO. Três caminhos possíveis, e só um está certo:
--
--   descartar a linha    → esconde receita negativa e INFLA o faturamento
--   manter sem flag      → polui toda soma que alguém fizer daqui para frente
--   sinalizar e manter   → correto: quem analisa decide se quer bruto ou líquido
--
-- A escolha muda o número que o diretor vê. Vamos de sinalizar.

CREATE OR REPLACE TABLE lakehouse_rotaperfume.silver.produtos
COMMENT 'Catálogo de SKUs com tipos corretos e descontinuação explícita.'
AS
SELECT
    trim(sku)           AS sku,
    trim(descricao)     AS descricao,
    trim(categoria)     AS categoria,
    trim(marca)         AS marca,
    trim(nota_olfativa) AS nota_olfativa,
    trim(unidade)       AS unidade,
    CAST(preco_tabela    AS DECIMAL(18,2)) AS preco_tabela,
    CAST(custo_unitario  AS DECIMAL(18,2)) AS custo_unitario,
    try_to_date(data_lancamento, 'yyyy-MM-dd') AS data_lancamento,
    (trim(ativo) = 'S')                        AS ativo,
    (trim(ativo) = 'N')                        AS descontinuado,
    current_timestamp() AS _processado_em,
    (SELECT count(*) FROM lakehouse_rotaperfume.bronze.produtos) AS _linhas_origem
FROM lakehouse_rotaperfume.bronze.produtos;

CREATE OR REPLACE TABLE lakehouse_rotaperfume.silver.itens_pedido
COMMENT 'Item de pedido com devolução sinalizada (nunca descartada) e SKU descontinuado marcado.'
AS
SELECT
    CAST(i.item_id  AS INT) AS item_id,
    CAST(i.pedido_id AS INT) AS pedido_id,
    trim(i.sku)              AS sku,

    CAST(i.quantidade AS INT)      AS quantidade,       -- como veio: pode ser negativa
    abs(CAST(i.quantidade AS INT)) AS quantidade_abs,   -- para contar peça
    (CAST(i.quantidade AS INT) < 0) AS devolucao,       -- a flag que salva o número

    CAST(i.preco_praticado AS DECIMAL(18,2)) AS preco_praticado,
    CAST(i.desconto_pct    AS DECIMAL(9,4))  AS desconto_pct,
    CAST(i.valor_bruto     AS DECIMAL(18,2)) AS valor_bruto,

    -- Vender SKU descontinuado não é erro do dado: é fato do negócio, e o
    -- comercial precisa saber. Marcamos, não corrigimos.
    coalesce(p.descontinuado, FALSE) AS sku_descontinuado,

    current_timestamp() AS _processado_em,
    (SELECT count(*) FROM lakehouse_rotaperfume.bronze.itens_pedido) AS _linhas_origem
FROM lakehouse_rotaperfume.bronze.itens_pedido i
LEFT JOIN lakehouse_rotaperfume.silver.produtos p ON p.sku = trim(i.sku);

ALTER TABLE lakehouse_rotaperfume.silver.itens_pedido
  ADD CONSTRAINT quantidade_abs_positiva CHECK (quantidade_abs > 0);

ALTER TABLE lakehouse_rotaperfume.silver.itens_pedido ALTER COLUMN devolucao
  COMMENT 'TRUE quando a quantidade veio negativa na origem. Devolução NUNCA é descartada: quem analisa decide se soma o bruto ou o líquido.';
ALTER TABLE lakehouse_rotaperfume.silver.itens_pedido ALTER COLUMN quantidade_abs
  COMMENT 'Quantidade em valor absoluto, para contagem de peça. Para valor financeiro use quantidade, que preserva o sinal.';
ALTER TABLE lakehouse_rotaperfume.silver.itens_pedido ALTER COLUMN sku_descontinuado
  COMMENT 'TRUE quando o produto vendido já estava inativo no cadastro. Fato do negócio, não erro de dado.';
