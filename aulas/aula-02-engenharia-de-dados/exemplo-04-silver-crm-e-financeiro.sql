-- ============================================
-- EXEMPLO 04: Silver do CRM e do financeiro
-- ============================================
-- Conceito: vigência temporal, NULL como informação, tipagem de data
-- Pergunta de negócio: quem atende quem, e o que já entrou em caixa?
-- Conexão com a aula 03: visitas e funil viram feature; pagamento vira fluxo
--
-- Rode com:
--   python3 scripts/run_sql.py aulas/aula-02-engenharia-de-dados/exemplo-04-silver-crm-e-financeiro.sql

CREATE OR REPLACE TABLE rota_perfume.silver.vendedores AS
SELECT
    CAST(vendedor_id AS INT)                                AS vendedor_id,
    nome, regiao, uf,
    try_to_date(data_admissao, 'yyyy-MM-dd')                AS data_admissao,
    -- vazio aqui não é dado faltando: significa que a pessoa continua na casa
    try_to_date(data_desligamento, 'yyyy-MM-dd')            AS data_desligamento,
    try_to_date(data_desligamento, 'yyyy-MM-dd') IS NULL    AS ativo,
    CAST(meta_mensal AS DECIMAL(18,2))                      AS meta_mensal
FROM rota_perfume.bronze.vendedores;


CREATE OR REPLACE TABLE rota_perfume.silver.carteira AS
SELECT
    CAST(c.carteira_id AS INT)                              AS carteira_id,
    CAST(c.cliente_id AS INT)                               AS cliente_id,
    CAST(c.vendedor_id AS INT)                              AS vendedor_id,
    try_to_date(c.data_inicio, 'yyyy-MM-dd')                AS data_inicio,
    try_to_date(c.data_fim, 'yyyy-MM-dd')                   AS data_fim,
    try_to_date(c.data_fim, 'yyyy-MM-dd') IS NULL           AS vigente,
    -- Sujeira 9: carteira aberta apontando para vendedor que já saiu.
    -- Não dá para "corrigir" — é problema de processo. Marcamos para o
    -- comercial ver que 441 clientes estão sem dono de verdade.
    try_to_date(c.data_fim, 'yyyy-MM-dd') IS NULL
      AND v.data_desligamento IS NOT NULL                   AS orfa
FROM rota_perfume.bronze.carteira c
LEFT JOIN rota_perfume.silver.vendedores v ON v.vendedor_id = CAST(c.vendedor_id AS INT);


CREATE OR REPLACE TABLE rota_perfume.silver.visitas AS
SELECT
    CAST(visita_id AS INT)                                  AS visita_id,
    CAST(cliente_id AS INT)                                 AS cliente_id,
    CAST(vendedor_id AS INT)                                AS vendedor_id,
    try_to_date(data_visita, 'yyyy-MM-dd')                  AS data_visita,
    resultado,
    resultado = 'Pedido realizado'                          AS converteu,
    CAST(duracao_min AS INT)                                AS duracao_min
FROM rota_perfume.bronze.visitas;


CREATE OR REPLACE TABLE rota_perfume.silver.oportunidades AS
SELECT
    CAST(oportunidade_id AS INT)                            AS oportunidade_id,
    CAST(cliente_id AS INT)                                 AS cliente_id,
    CAST(vendedor_id AS INT)                                AS vendedor_id,
    origem, etapa,
    try_to_date(data_abertura, 'yyyy-MM-dd')                AS data_abertura,
    try_to_date(data_fechamento, 'yyyy-MM-dd')              AS data_fechamento,
    CAST(probabilidade_pct AS INT)                          AS probabilidade_pct,
    CAST(valor_estimado AS DECIMAL(18,2))                   AS valor_estimado,
    CAST(ciclo_dias AS INT)                                 AS ciclo_dias,
    nullif(motivo_perda, '')                                AS motivo_perda,
    etapa = 'Fechado ganho'                                 AS ganha,
    etapa = 'Fechado perdido'                               AS perdida,
    etapa NOT IN ('Fechado ganho', 'Fechado perdido')       AS aberta
FROM rota_perfume.bronze.oportunidades;


CREATE OR REPLACE TABLE rota_perfume.silver.pagamentos AS
SELECT
    CAST(pagamento_id AS INT)                               AS pagamento_id,
    CAST(pedido_id AS INT)                                  AS pedido_id,
    forma_pagamento,
    CAST(parcelas AS INT)                                   AS parcelas,
    CAST(valor AS DECIMAL(18,2))                            AS valor,
    CAST(taxa_pct AS DECIMAL(9,2))                          AS taxa_pct,
    CAST(valor_liquido AS DECIMAL(18,2))                    AS valor_liquido,
    -- o que a operadora fica: some no fluxo de caixa e ninguém vê no ERP
    CAST(valor AS DECIMAL(18,2))
      - CAST(valor_liquido AS DECIMAL(18,2))                AS custo_financeiro,
    try_to_date(data_vencimento, 'yyyy-MM-dd')              AS data_vencimento,
    try_to_date(data_pagamento, 'yyyy-MM-dd')               AS data_pagamento,
    status_pagamento,
    try_to_date(data_pagamento, 'yyyy-MM-dd') IS NULL       AS em_aberto,
    datediff(try_to_date(data_pagamento, 'yyyy-MM-dd'),
             try_to_date(data_vencimento, 'yyyy-MM-dd'))    AS dias_de_atraso
FROM rota_perfume.bronze.pagamentos;


-- ----------------------------------------------------------------------------
SELECT
    (SELECT COUNT(*) FROM rota_perfume.silver.vendedores WHERE NOT ativo)  AS vendedores_desligados,
    (SELECT COUNT(*) FROM rota_perfume.silver.carteira WHERE orfa)         AS carteiras_orfas,
    (SELECT COUNT(*) FROM rota_perfume.silver.visitas WHERE converteu)     AS visitas_com_pedido,
    (SELECT COUNT(*) FROM rota_perfume.silver.oportunidades WHERE aberta)  AS funil_aberto,
    (SELECT COUNT(*) FROM rota_perfume.silver.pagamentos WHERE em_aberto)  AS a_receber,
    (SELECT ROUND(SUM(custo_financeiro), 2) FROM rota_perfume.silver.pagamentos) AS custo_financeiro_total;
