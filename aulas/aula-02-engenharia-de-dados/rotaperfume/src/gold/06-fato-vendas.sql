-- Gold · fato_vendas
--
-- ════════════════════ O CONTRATO, ESCRITO ANTES DO SQL ════════════════════
--
--   GRANULARIDADE  uma linha por ITEM de pedido
--   FILTRO         exclui pedido cancelado. NÃO exclui devolução.
--   DIMENSÕES      data, ano, mês, canal, cliente, segmento, cidade,
--                  vendedor, sku, categoria, marca, nota olfativa
--   MÉTRICAS       quantidade, preço praticado, receita, custo, margem
--   PARTIÇÃO       ano, mes
--
-- Escrever isso numa frase antes de abrir o editor evita seis meses de
-- discussão sobre o que a tabela significa. Se você não consegue escrever o
-- contrato, você ainda não sabe o que está construindo.
--
-- ─────────────── POR QUE A DEVOLUÇÃO FICA DENTRO DO FATO ───────────────
--
-- Tirar devolução parece certo: "receita é o que vendeu". Mas aí a gold soma
-- R$ 103,6 mi e a silver soma R$ 102,3 mi — R$ 1,26 milhão de diferença entre
-- duas camadas do MESMO pipeline. Um dia alguém compara os dois relatórios
-- numa reunião, e a discussão vira sobre qual sistema está certo.
--
-- Ela fica dentro, com valor negativo e flag. Quem quer o bruto vendido pede:
--     SUM(receita) FILTER (WHERE NOT devolucao)
-- Os dois números existem, e os dois reconciliam.

CREATE OR REPLACE TABLE lakehouse_rotaperfume.gold.fato_vendas
PARTITIONED BY (ano, mes)
COMMENT 'Fato de vendas no grão de item de pedido. Exclui pedido cancelado; inclui devolução com valor negativo e flag. Soma exatamente a receita da silver.'
AS
-- O cliente do pedido nem sempre é o cliente que sobreviveu à limpeza.
--
-- A silver deduplicou 40 CNPJs recadastrados com id novo e manteve o cadastro
-- mais antigo. Os pedidos feitos com o id descartado continuam apontando para
-- ele — e um JOIN direto com a dimensão jogaria essas vendas fora. São 153
-- itens e R$ 71.451,60 que sumiriam sem erro nenhum.
--
-- Foi para isto que a silver guardou `cliente_ids_duplicados`. Aqui ela deixa
-- de ser rastreabilidade e vira chave: o pedido órfão é remapeado para o
-- cadastro certo, e a venda entra no fato no cliente a que pertence.
--
-- Quem denuncia se isto sair é o teste 1 — receita da gold = receita da
-- silver. Um fato de vendas que perde venda não pode passar despercebido.
WITH mapa_cliente AS (
  SELECT explode(cliente_ids_duplicados) AS id_antigo,
         cliente_id                      AS id_atual
  FROM lakehouse_rotaperfume.silver.clientes
  WHERE size(cliente_ids_duplicados) > 0
)
SELECT
    -- chaves. cliente_id é o RESOLVIDO: pedido órfão entra no cadastro certo.
    i.item_id, i.pedido_id,
    COALESCE(m.id_atual, p.cliente_id) AS cliente_id,
    p.vendedor_id, i.sku,

    -- dimensões de tempo
    p.data_pedido, p.ano, p.mes,

    -- dimensões de negócio, desnormalizadas de propósito: o consumidor da gold
    -- não deveria precisar de JOIN para responder "receita por marca".
    p.canal,
    c.razao_social, c.segmento, c.cidade, c.uf,
    pr.categoria, pr.marca, pr.nota_olfativa,

    -- métricas
    i.quantidade,
    i.preco_praticado,
    i.valor_bruto                                        AS receita,
    CAST(i.quantidade * pr.custo_unitario AS DECIMAL(18,2)) AS custo,
    CAST(i.valor_bruto - (i.quantidade * pr.custo_unitario) AS DECIMAL(18,2)) AS margem,

    i.devolucao,
    i.sku_descontinuado,
    current_timestamp() AS _processado_em
FROM lakehouse_rotaperfume.silver.itens_pedido i
JOIN lakehouse_rotaperfume.silver.pedidos   p  ON p.pedido_id  = i.pedido_id
JOIN lakehouse_rotaperfume.silver.produtos  pr ON pr.sku       = i.sku
LEFT JOIN mapa_cliente                      m  ON m.id_antigo = p.cliente_id
JOIN lakehouse_rotaperfume.gold.dim_cliente c  ON c.cliente_id = COALESCE(m.id_atual, p.cliente_id)
WHERE NOT p.cancelado;

ALTER TABLE lakehouse_rotaperfume.gold.fato_vendas ALTER COLUMN receita
  COMMENT 'Valor do item vendido. NEGATIVO quando é devolução. Para o bruto vendido use SUM(receita) FILTER (WHERE NOT devolucao).';
ALTER TABLE lakehouse_rotaperfume.gold.fato_vendas ALTER COLUMN custo
  COMMENT 'Quantidade multiplicada pelo custo unitário do produto no cadastro. Não considera frete nem custo de aquisição variável.';
ALTER TABLE lakehouse_rotaperfume.gold.fato_vendas ALTER COLUMN margem
  COMMENT 'Receita menos custo do produto. NÃO considera desconto comercial já aplicado no preço, nem frete, nem taxa de pagamento.';
ALTER TABLE lakehouse_rotaperfume.gold.fato_vendas ALTER COLUMN devolucao
  COMMENT 'TRUE quando a linha é uma devolução (quantidade e receita negativas). Devolução permanece no fato de propósito, para reconciliar com a silver.';
ALTER TABLE lakehouse_rotaperfume.gold.fato_vendas ALTER COLUMN quantidade
  COMMENT 'Quantidade vendida, negativa em devolução. Para contar peça movimentada use ABS(quantidade).';

-- O resto do metadado. Não é capricho: COMMENT é a INTERFACE do agente de IA.
-- Ele não lê o nome da coluna e adivinha — ele lê a descrição e decide. Coluna
-- sem comentário é coluna que o Genie vai usar errado, com confiança.
ALTER TABLE lakehouse_rotaperfume.gold.fato_vendas ALTER COLUMN item_id
  COMMENT 'Identificador do item dentro do pedido. Chave primária do fato.';
ALTER TABLE lakehouse_rotaperfume.gold.fato_vendas ALTER COLUMN pedido_id
  COMMENT 'Identificador do pedido no ERP. Use COUNT(DISTINCT pedido_id) para contar pedidos.';
ALTER TABLE lakehouse_rotaperfume.gold.fato_vendas ALTER COLUMN cliente_id
  COMMENT 'Identificador do cliente. Liga com gold.dim_cliente.';
ALTER TABLE lakehouse_rotaperfume.gold.fato_vendas ALTER COLUMN vendedor_id
  COMMENT 'Vendedor responsável pelo pedido. Liga com gold.dim_vendedor.';
ALTER TABLE lakehouse_rotaperfume.gold.fato_vendas ALTER COLUMN sku
  COMMENT 'Código do produto vendido. Liga com gold.dim_produto.';
ALTER TABLE lakehouse_rotaperfume.gold.fato_vendas ALTER COLUMN data_pedido
  COMMENT 'Data em que o pedido foi feito. Período da base: setembro/2024 a agosto/2026.';
ALTER TABLE lakehouse_rotaperfume.gold.fato_vendas ALTER COLUMN ano
  COMMENT 'Ano do pedido. Coluna de partição.';
ALTER TABLE lakehouse_rotaperfume.gold.fato_vendas ALTER COLUMN mes
  COMMENT 'Mês do pedido, de 1 a 12. Coluna de partição. Abril, junho e outubro são os picos do setor.';
ALTER TABLE lakehouse_rotaperfume.gold.fato_vendas ALTER COLUMN canal
  COMMENT 'Canal de entrada do pedido: Visita, WhatsApp, E-commerce ou Televendas.';
ALTER TABLE lakehouse_rotaperfume.gold.fato_vendas ALTER COLUMN razao_social
  COMMENT 'Nome do cliente que comprou, já padronizado na silver.';
ALTER TABLE lakehouse_rotaperfume.gold.fato_vendas ALTER COLUMN segmento
  COMMENT 'Tipo de varejo do cliente: Perfumaria, Farmácia, Loja de shopping, Revendedora autônoma, E-commerce, Salão de beleza, Loja de departamento ou Quiosque.';
ALTER TABLE lakehouse_rotaperfume.gold.fato_vendas ALTER COLUMN cidade
  COMMENT 'Cidade do cliente. A operação cobre 12 capitais e Campinas.';
ALTER TABLE lakehouse_rotaperfume.gold.fato_vendas ALTER COLUMN uf
  COMMENT 'Unidade federativa do cliente.';
ALTER TABLE lakehouse_rotaperfume.gold.fato_vendas ALTER COLUMN categoria
  COMMENT 'Categoria do produto: Eau de Parfum, Óleo Concentrado, Bakhoor, Kit Presente, entre outras. A margem varia muito entre elas.';
ALTER TABLE lakehouse_rotaperfume.gold.fato_vendas ALTER COLUMN marca
  COMMENT 'Marca do produto. A receita concentra muito: Layali é a líder.';
ALTER TABLE lakehouse_rotaperfume.gold.fato_vendas ALTER COLUMN nota_olfativa
  COMMENT 'Família olfativa do perfume: amadeirado, oriental, floral, cítrico e outras.';
ALTER TABLE lakehouse_rotaperfume.gold.fato_vendas ALTER COLUMN preco_praticado
  COMMENT 'Preço unitário efetivamente cobrado, já com o desconto comercial aplicado.';
ALTER TABLE lakehouse_rotaperfume.gold.fato_vendas ALTER COLUMN sku_descontinuado
  COMMENT 'TRUE quando o produto vendido já estava fora de linha no cadastro.';
ALTER TABLE lakehouse_rotaperfume.gold.fato_vendas ALTER COLUMN _processado_em
  COMMENT 'Momento em que esta linha foi gerada pelo pipeline. Coluna técnica.';
