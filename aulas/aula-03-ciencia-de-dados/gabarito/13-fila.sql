-- ═══════════════════════════════════════════════════════════════════════
-- ML · a fila da semana
--
-- O score está pronto e é inútil. `0,8412` não é uma ação: o vendedor não faz
-- nada com um número entre zero e um.
--
-- Aqui ele vira lista: quem ligar, em que ordem, por quê e o que oferecer. É o
-- último metro — onde os projetos de ML morrem — e é a única parte da noite
-- que alguém de fora do time de dados vai abrir.
-- ═══════════════════════════════════════════════════════════════════════


-- ── 1 · A FILA ────────────────────────────────────────────────────────
--
-- A ORDEM DAS OPERAÇÕES É O QUE IMPORTA AQUI:
--
--   1º  junta a carteira e DESCARTA quem não é elegível
--   2º  ORDER BY score DESC LIMIT 200
--   3º  ROW_NUMBER() por vendedor, para dar a ordem de ligação
--
-- Invertendo os dois primeiros, a fila sai com ~172 linhas em vez de 200:
-- seis dos 42 vendedores estão desligados com carteira ainda vinculada — a
-- nona das dez sujeiras da noite 2 — e levam junto os clientes deles. O teste
-- 1 lá embaixo derruba o job se isso acontecer.
--
-- E a fila é GLOBAL, não uma cota por vendedor. Se a carteira do João está
-- quente e a do Pedro está fria, cota igual obrigaria o João a deixar cliente
-- quente na mesa para o Pedro ligar para cliente frio. A fila é global; a
-- capacidade é que é por pessoa.
CREATE OR REPLACE TABLE lakehouse_rotaperfume.gold.fila_semanal
COMMENT 'Os 200 clientes de maior propensão da base inteira, divididos pela carteira de cada vendedor, com o motivo escrito em português e o que oferecer. É o que o vendedor abre na segunda de manhã.'
AS
WITH elegiveis AS (
  -- só cliente com carteira vigente e vendedor na ativa
  SELECT s.cliente_id, s.score, s.faixa, s.versao,
         v.nome AS vendedor
  FROM lakehouse_rotaperfume.gold.score_propensao s
  JOIN lakehouse_rotaperfume.silver.carteira c
    ON c.cliente_id = s.cliente_id
   AND c.vigente
   AND NOT c.orfao_vendedor_desligado
  JOIN lakehouse_rotaperfume.silver.vendedores v
    ON v.vendedor_id = c.vendedor_id
   AND v.ativo
),
os_200 AS (
  SELECT * FROM elegiveis ORDER BY score DESC LIMIT 200
),
-- a marca que o cliente mais comprou, e o SKU dela que ele parou de comprar
receita_por_marca AS (
  SELECT cliente_id, marca, sum(receita) AS receita,
         row_number() OVER (PARTITION BY cliente_id ORDER BY sum(receita) DESC) AS ordem_marca
  FROM lakehouse_rotaperfume.gold.fato_vendas
  GROUP BY cliente_id, marca
),
marca_preferida AS (
  SELECT cliente_id, marca FROM receita_por_marca WHERE ordem_marca = 1
),
comprou_recente AS (
  SELECT DISTINCT cliente_id, sku
  FROM lakehouse_rotaperfume.gold.fato_vendas
  WHERE data_pedido >= date_sub(DATE'2026-08-31', 90)
),
sku_esquecido AS (
  SELECT f.cliente_id, f.sku, sum(f.receita) AS receita,
         row_number() OVER (PARTITION BY f.cliente_id ORDER BY sum(f.receita) DESC) AS ordem_sku
  FROM lakehouse_rotaperfume.gold.fato_vendas f
  JOIN marca_preferida mp ON mp.cliente_id = f.cliente_id AND mp.marca = f.marca
  LEFT ANTI JOIN comprou_recente cr ON cr.cliente_id = f.cliente_id AND cr.sku = f.sku
  GROUP BY f.cliente_id, f.sku
),
-- o estoque é um snapshot SEMANAL: vale o mais recente de cada SKU
estoque_atual AS (
  SELECT sku, saldo, ruptura
  FROM lakehouse_rotaperfume.silver.estoque
  QUALIFY row_number() OVER (PARTITION BY sku ORDER BY data_snapshot DESC) = 1
)
SELECT
    t.vendedor,
    row_number() OVER (PARTITION BY t.vendedor ORDER BY t.score DESC) AS ordem,
    t.cliente_id,
    dc.razao_social,
    dc.cidade,
    dc.uf,
    t.score,
    t.faixa,
    f.ticket_medio,

    -- O motivo, em português, com os números REAIS do cliente dentro. Modelo
    -- que não explica não é usado: fica um mês na tela e some.
    -- A ORDEM DO CASE decide a qualidade da lista, e é contraintuitiva: vai do
    -- sinal mais RARO para o mais comum. Escrito na ordem "natural", com
    -- lançamento em terceiro, 176 dos 200 contatos saíam com o mesmo motivo —
    -- e motivo repetido não ajuda ninguém a discar.
    CASE
      WHEN f.atraso_relativo > 3 THEN concat(
        'Compra a cada ', format_number(f.intervalo_medio_dias, 0),
        ' dias e está há ', format_number(f.recencia_dias, 0),
        ' sem pedido. Risco de perder para o concorrente.')
      WHEN f.atraso_relativo > 1.5 THEN concat(
        'Está ', format_number(f.atraso_relativo, 1),
        ' vezes mais atrasado que o ritmo dele.')
      WHEN f.pedidos_ultimos_90d >= 3 THEN concat(
        format_number(f.pedidos_ultimos_90d, 0),
        ' pedidos nos últimos 90 dias. Está em ciclo curto — não deixe esfriar.')
      WHEN f.valor_total >= 150000 THEN concat(
        'Cliente grande, R$ ', format_number(f.valor_total, 0),
        ' no histórico. Manter próximo.')
      WHEN f.conversao_visita > 0.5 THEN concat(
        'Mais da metade das visitas viram pedido (',
        format_number(100 * f.conversao_visita, 0), '%). Vale a ida.')
      WHEN f.comprou_lancamento = 1 THEN
        'Comprou lançamento recente. Alta chance de repetir.'
      -- O ELSE não é formalidade: motivo nulo derruba o teste 2.
      ELSE 'Dentro do ritmo. Contato de manutenção.'
    END AS motivo,

    CASE
      WHEN se.sku IS NULL THEN 'Sem sugestão — cliente comprou tudo que costuma comprar nos últimos 90 dias.'
      WHEN ea.ruptura OR coalesce(ea.saldo, 0) = 0 THEN concat(
        se.sku, ' (', mp.marca, ') — parou de comprar. ATENÇÃO: em ruptura.')
      ELSE concat(
        se.sku, ' (', mp.marca, ') — parou de comprar. ',
        format_number(ea.saldo, 0), ' em estoque.')
    END AS sugestao,

    DATE'2026-08-31' AS _referencia,
    t.versao
FROM os_200 t
JOIN lakehouse_rotaperfume.gold.dim_cliente     dc ON dc.cliente_id = t.cliente_id
JOIN lakehouse_rotaperfume.gold.features_cliente f  ON f.cliente_id  = t.cliente_id
LEFT JOIN marca_preferida mp ON mp.cliente_id = t.cliente_id
LEFT JOIN sku_esquecido   se ON se.cliente_id = t.cliente_id AND se.ordem_sku = 1
LEFT JOIN estoque_atual   ea ON ea.sku = se.sku;

ALTER TABLE lakehouse_rotaperfume.gold.fila_semanal ALTER COLUMN vendedor
  COMMENT 'Nome do vendedor dono da carteira. Só vendedor ativo entra na fila.';
ALTER TABLE lakehouse_rotaperfume.gold.fila_semanal ALTER COLUMN ordem
  COMMENT 'Ordem de ligação dentro da carteira do vendedor, do maior score para o menor.';
ALTER TABLE lakehouse_rotaperfume.gold.fila_semanal ALTER COLUMN score
  COMMENT 'Probabilidade de o cliente fazer pedido nos próximos 7 dias, de 0 a 1.';
ALTER TABLE lakehouse_rotaperfume.gold.fila_semanal ALTER COLUMN motivo
  COMMENT 'Por que este cliente está na lista, escrito para o vendedor ler antes de discar.';
ALTER TABLE lakehouse_rotaperfume.gold.fila_semanal ALTER COLUMN sugestao
  COMMENT 'O SKU da marca preferida que o cliente parou de comprar, com o saldo em estoque.';

-- As demais também: é o COMMENT que o Genie lê para responder sem inventar.
ALTER TABLE lakehouse_rotaperfume.gold.fila_semanal ALTER COLUMN cliente_id
  COMMENT 'Identificador do cliente, o mesmo de gold.dim_cliente.';
ALTER TABLE lakehouse_rotaperfume.gold.fila_semanal ALTER COLUMN razao_social
  COMMENT 'Nome do cliente como o vendedor o conhece.';
ALTER TABLE lakehouse_rotaperfume.gold.fila_semanal ALTER COLUMN cidade
  COMMENT 'Cidade do cliente. Serve para agrupar as visitas de um mesmo dia.';
ALTER TABLE lakehouse_rotaperfume.gold.fila_semanal ALTER COLUMN uf
  COMMENT 'Unidade federativa do cliente.';
ALTER TABLE lakehouse_rotaperfume.gold.fila_semanal ALTER COLUMN faixa
  COMMENT 'Faixa do score em quartis: Fria, Morna, Quente, Muito quente.';
ALTER TABLE lakehouse_rotaperfume.gold.fila_semanal ALTER COLUMN ticket_medio
  COMMENT 'Quanto o cliente gasta por pedido, em média, no histórico dele.';
ALTER TABLE lakehouse_rotaperfume.gold.fila_semanal ALTER COLUMN _referencia
  COMMENT 'Data de corte usada para montar a fila. O "hoje" do dataset é 2026-08-31.';
ALTER TABLE lakehouse_rotaperfume.gold.fila_semanal ALTER COLUMN versao
  COMMENT 'Versão do modelo no Unity Catalog que gerou o score desta linha.';


-- ── 2 · AS QUATRO FERRAMENTAS ─────────────────────────────────────────
--
-- O agente não inventa: ele consulta. Cada função é uma pergunta que o
-- vendedor faz, com contrato e COMMENT — e é o COMMENT que o agente lê para
-- saber quando usar cada uma.
--
-- Todo parâmetro leva prefixo p_. Parâmetro com o mesmo nome de uma coluna
-- deixa o corpo da função ambíguo e o CREATE falha.

CREATE OR REPLACE FUNCTION lakehouse_rotaperfume.gold.priorizar_carteira(
  p_vendedor STRING COMMENT 'Nome do vendedor, como aparece em fila_semanal.',
  p_quantos  INT    COMMENT 'Quantos clientes trazer, do maior score para o menor.'
)
RETURNS TABLE (ordem INT, razao_social STRING, cidade STRING, score DOUBLE,
               faixa STRING, motivo STRING, sugestao STRING)
COMMENT 'A lista de ligações da semana de um vendedor, em ordem de prioridade, com o motivo e o que oferecer. Use quando perguntarem para quem ligar.'
-- Nada de `LIMIT p_quantos`: o Databricks exige que o LIMIT seja constante e
-- recusa a criação com INVALID_LIMIT_LIKE_EXPRESSION. Como a fila já vem
-- numerada, o corte vira um filtro na coluna `ordem`.
RETURN
  SELECT CAST(ordem AS INT), razao_social, cidade, score, faixa, motivo, sugestao
  FROM lakehouse_rotaperfume.gold.fila_semanal
  WHERE vendedor = p_vendedor
    AND ordem <= p_quantos
  ORDER BY ordem;

CREATE OR REPLACE FUNCTION lakehouse_rotaperfume.gold.contexto_cliente(
  p_cliente_id INT COMMENT 'Identificador do cliente.'
)
RETURNS TABLE (razao_social STRING, cidade STRING, uf STRING,
               pedidos DOUBLE, valor_total DOUBLE, ticket_medio DOUBLE,
               recencia_dias DOUBLE, intervalo_medio_dias DOUBLE,
               marcas_distintas DOUBLE)
COMMENT 'Histórico do cliente: quanto compra, de quanto em quanto tempo e há quantos dias não pede. Use antes de ligar, para saber com quem se está falando.'
RETURN
  SELECT dc.razao_social, dc.cidade, dc.uf,
         f.frequencia_pedidos, f.valor_total, f.ticket_medio,
         f.recencia_dias, f.intervalo_medio_dias, f.marcas_distintas
  FROM lakehouse_rotaperfume.gold.features_cliente f
  JOIN lakehouse_rotaperfume.gold.dim_cliente dc ON dc.cliente_id = f.cliente_id
  WHERE f.cliente_id = p_cliente_id;

CREATE OR REPLACE FUNCTION lakehouse_rotaperfume.gold.sugerir_produtos(
  p_cliente_id INT COMMENT 'Identificador do cliente.'
)
RETURNS TABLE (sku STRING, marca STRING, categoria STRING,
               receita_historica DOUBLE, ultima_compra DATE)
COMMENT 'O que o cliente comprava e parou de comprar nos últimos 90 dias, da maior receita para a menor. Use para montar a oferta da ligação.'
RETURN
  SELECT f.sku, max(f.marca), max(f.categoria),
         sum(f.receita), max(f.data_pedido)
  FROM lakehouse_rotaperfume.gold.fato_vendas f
  WHERE f.cliente_id = p_cliente_id
  GROUP BY f.sku
  HAVING max(f.data_pedido) < date_sub(DATE'2026-08-31', 90)
  ORDER BY sum(f.receita) DESC
  LIMIT 10;

CREATE OR REPLACE FUNCTION lakehouse_rotaperfume.gold.checar_disponibilidade(
  p_sku STRING COMMENT 'Código do SKU.'
)
RETURNS TABLE (sku STRING, descricao STRING, marca STRING,
               saldo INT, ruptura BOOLEAN, data_snapshot DATE)
COMMENT 'Saldo em estoque do SKU no snapshot mais recente, com a marcação de ruptura. Use antes de prometer prazo ao cliente.'
RETURN
  SELECT e.sku, dp.descricao, dp.marca, e.saldo, e.ruptura, e.data_snapshot
  FROM lakehouse_rotaperfume.silver.estoque e
  LEFT JOIN lakehouse_rotaperfume.gold.dim_produto dp ON dp.sku = e.sku
  WHERE e.sku = p_sku
  QUALIFY row_number() OVER (PARTITION BY e.sku ORDER BY e.data_snapshot DESC) = 1;


-- ── 3 · OS TESTES QUE QUEBRAM O JOB ───────────────────────────────────
--
-- Mesma regra da noite 2: melhor o dashboard ficar com o dado de ontem do que
-- com o dado errado de hoje. Uma fila torta é pior que fila nenhuma — o
-- vendedor liga, não vende, e para de confiar na lista para sempre.

SELECT '1 · a fila tem 200 contatos' AS teste,
       CAST(linhas AS STRING) AS calculado, '200' AS esperado,
       CASE WHEN linhas = 200 THEN 'PASSOU'
            ELSE raise_error(concat('A fila saiu com ', linhas, ' linhas em vez de 200. ',
                 'O filtro de carteira vigente rodou DEPOIS do LIMIT 200?'))
       END AS resultado
FROM (SELECT count(*) AS linhas FROM lakehouse_rotaperfume.gold.fila_semanal);

SELECT '2 · todo contato tem motivo' AS teste,
       CAST(sem_motivo AS STRING) AS calculado, '0' AS esperado,
       CASE WHEN sem_motivo = 0 THEN 'PASSOU'
            ELSE raise_error(concat(sem_motivo, ' contatos sem motivo. ',
                 'Faltou o ELSE no CASE WHEN — e lista sem motivo não é usada.'))
       END AS resultado
FROM (SELECT count(*) AS sem_motivo FROM lakehouse_rotaperfume.gold.fila_semanal
      WHERE motivo IS NULL OR trim(motivo) = '');

SELECT '3 · score dentro de [0, 1]' AS teste,
       CAST(fora AS STRING) AS calculado, '0' AS esperado,
       CASE WHEN fora = 0 THEN 'PASSOU'
            ELSE raise_error(concat(fora, ' scores fora do intervalo [0,1]. ',
                 'O modelo devolveu classe em vez de probabilidade?'))
       END AS resultado
FROM (SELECT count(*) AS fora FROM lakehouse_rotaperfume.gold.fila_semanal
      WHERE score < 0 OR score > 1 OR score IS NULL);
