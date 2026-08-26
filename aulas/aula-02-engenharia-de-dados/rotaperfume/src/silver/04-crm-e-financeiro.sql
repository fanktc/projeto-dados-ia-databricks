-- Silver · CRM e financeiro
--
-- Seis tabelas de uma vez, porque o tratamento delas é rotina: tipo certo,
-- data com try_to_date, texto com trim. Só duas exigem decisão de negócio:
--
--   carteira  441 vínculos estão "vigentes" (data_fim nula) para vendedor que
--             já foi DESLIGADO. Não é para consertar: é para expor. A coluna
--             vigente respeita as duas datas, e o gestor vê o buraco.
--   estoque   ruptura vira boolean, e passa a ser somável.

CREATE OR REPLACE TABLE lakehouse_rotaperfume.silver.vendedores
COMMENT 'Equipe comercial, com admissão, desligamento e meta tipados.'
AS
SELECT
    CAST(vendedor_id AS INT) AS vendedor_id,
    trim(nome)   AS nome,
    trim(regiao) AS regiao,
    trim(uf)     AS uf,
    try_to_date(data_admissao,     'yyyy-MM-dd') AS data_admissao,
    try_to_date(data_desligamento, 'yyyy-MM-dd') AS data_desligamento,
    CAST(meta_mensal AS DECIMAL(18,2))           AS meta_mensal,
    (data_desligamento IS NULL OR trim(data_desligamento) = '') AS ativo,
    current_timestamp() AS _processado_em,
    (SELECT count(*) FROM lakehouse_rotaperfume.bronze.vendedores) AS _linhas_origem
FROM lakehouse_rotaperfume.bronze.vendedores;

CREATE OR REPLACE TABLE lakehouse_rotaperfume.silver.carteira
COMMENT 'Vínculo cliente × vendedor com vigência real: respeita o desligamento do vendedor, não só a data_fim do vínculo.'
AS
SELECT
    CAST(c.carteira_id AS INT) AS carteira_id,
    CAST(c.cliente_id  AS INT) AS cliente_id,
    CAST(c.vendedor_id AS INT) AS vendedor_id,
    try_to_date(c.data_inicio, 'yyyy-MM-dd') AS data_inicio,
    try_to_date(c.data_fim,    'yyyy-MM-dd') AS data_fim,

    -- Um vínculo só está de pé se ele não terminou E o vendedor ainda está na
    -- empresa. Confiar só em data_fim IS NULL deixa 441 carteiras "ativas" com
    -- vendedor desligado — e o cliente sem ninguém atendendo, sem ninguém ver.
    (try_to_date(c.data_fim, 'yyyy-MM-dd') IS NULL AND v.data_desligamento IS NULL) AS vigente,
    (try_to_date(c.data_fim, 'yyyy-MM-dd') IS NULL AND v.data_desligamento IS NOT NULL) AS orfao_vendedor_desligado,

    current_timestamp() AS _processado_em,
    (SELECT count(*) FROM lakehouse_rotaperfume.bronze.carteira) AS _linhas_origem
FROM lakehouse_rotaperfume.bronze.carteira c
LEFT JOIN lakehouse_rotaperfume.silver.vendedores v ON v.vendedor_id = CAST(c.vendedor_id AS INT);

CREATE OR REPLACE TABLE lakehouse_rotaperfume.silver.oportunidades
COMMENT 'Funil comercial: origem, etapa, valor estimado, ciclo e motivo de perda.'
AS
SELECT
    CAST(oportunidade_id AS INT) AS oportunidade_id,
    CAST(cliente_id      AS INT) AS cliente_id,
    CAST(vendedor_id     AS INT) AS vendedor_id,
    trim(origem) AS origem,
    trim(etapa)  AS etapa,
    try_to_date(data_abertura,  'yyyy-MM-dd') AS data_abertura,
    try_to_date(data_fechamento,'yyyy-MM-dd') AS data_fechamento,
    CAST(probabilidade_pct AS DECIMAL(9,4))  AS probabilidade_pct,
    CAST(valor_estimado    AS DECIMAL(18,2)) AS valor_estimado,
    CAST(ciclo_dias        AS INT)           AS ciclo_dias,
    nullif(trim(motivo_perda), '')           AS motivo_perda,
    (trim(etapa) = 'Fechado ganho')   AS ganha,
    (trim(etapa) = 'Fechado perdido') AS perdida,
    current_timestamp() AS _processado_em,
    (SELECT count(*) FROM lakehouse_rotaperfume.bronze.oportunidades) AS _linhas_origem
FROM lakehouse_rotaperfume.bronze.oportunidades;

CREATE OR REPLACE TABLE lakehouse_rotaperfume.silver.visitas
COMMENT 'Visitas do time comercial. Visita sem pedido é o dado mais subestimado de uma operação B2B.'
AS
SELECT
    CAST(visita_id   AS INT) AS visita_id,
    CAST(cliente_id  AS INT) AS cliente_id,
    CAST(vendedor_id AS INT) AS vendedor_id,
    try_to_date(data_visita, 'yyyy-MM-dd') AS data_visita,
    trim(resultado) AS resultado,
    CAST(duracao_min AS INT) AS duracao_min,
    -- Os valores vêm do ERP por extenso: 'Pedido realizado', 'Sem pedido',
    -- 'Cliente ausente', 'Reagendada', 'Apenas relacionamento'. Comparar com
    -- 'Pedido' faria a flag ser sempre FALSE — e flag sempre falsa não levanta
    -- erro nenhum: ela só faz o número ficar zero e ninguém perceber.
    (trim(resultado) = 'Pedido realizado') AS gerou_pedido,
    (trim(resultado) = 'Cliente ausente')  AS cliente_ausente,
    current_timestamp() AS _processado_em,
    (SELECT count(*) FROM lakehouse_rotaperfume.bronze.visitas) AS _linhas_origem
FROM lakehouse_rotaperfume.bronze.visitas;

CREATE OR REPLACE TABLE lakehouse_rotaperfume.silver.pagamentos
COMMENT 'Financeiro do pedido: forma, parcelas, taxa, vencimento e baixa. Base do mart de recebimento.'
AS
SELECT
    CAST(pagamento_id AS INT) AS pagamento_id,
    CAST(pedido_id    AS INT) AS pedido_id,
    trim(forma_pagamento)  AS forma_pagamento,
    trim(status_pagamento) AS status_pagamento,
    CAST(parcelas     AS INT)           AS parcelas,
    CAST(valor        AS DECIMAL(18,2)) AS valor,
    CAST(taxa_pct     AS DECIMAL(9,4))  AS taxa_pct,
    CAST(valor_liquido AS DECIMAL(18,2)) AS valor_liquido,
    try_to_date(data_vencimento, 'yyyy-MM-dd') AS data_vencimento,
    try_to_date(data_pagamento,  'yyyy-MM-dd') AS data_pagamento,
    (try_to_date(data_pagamento, 'yyyy-MM-dd') IS NOT NULL) AS recebido,
    datediff(try_to_date(data_pagamento,  'yyyy-MM-dd'),
             try_to_date(data_vencimento, 'yyyy-MM-dd'))    AS dias_de_atraso,
    current_timestamp() AS _processado_em,
    (SELECT count(*) FROM lakehouse_rotaperfume.bronze.pagamentos) AS _linhas_origem
FROM lakehouse_rotaperfume.bronze.pagamentos;

CREATE OR REPLACE TABLE lakehouse_rotaperfume.silver.estoque
COMMENT 'Snapshot semanal de saldo por SKU, com ruptura já somável.'
AS
SELECT
    try_to_date(data_snapshot, 'yyyy-MM-dd') AS data_snapshot,
    trim(sku)             AS sku,
    CAST(saldo AS INT)    AS saldo,
    (trim(ruptura) = 'S') AS ruptura,
    current_timestamp() AS _processado_em,
    (SELECT count(*) FROM lakehouse_rotaperfume.bronze.estoque) AS _linhas_origem
FROM lakehouse_rotaperfume.bronze.estoque;

ALTER TABLE lakehouse_rotaperfume.silver.carteira ALTER COLUMN vigente
  COMMENT 'Vínculo realmente de pé: sem data_fim E com o vendedor ainda na empresa.';
ALTER TABLE lakehouse_rotaperfume.silver.carteira ALTER COLUMN orfao_vendedor_desligado
  COMMENT 'Carteira sem data_fim cujo vendedor já foi desligado. O cliente ficou sem quem o atenda, e ninguém foi avisado.';
ALTER TABLE lakehouse_rotaperfume.silver.pagamentos ALTER COLUMN dias_de_atraso
  COMMENT 'Dias entre vencimento e pagamento. Negativo é adiantamento; nulo é título ainda em aberto.';
