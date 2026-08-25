-- Silver · clientes
--
-- A tabela mais suja do dataset, e a mais didática. Quatro problemas diferentes
-- na mesma tabela, cada um exigindo uma decisão distinta:
--
--   cnpj          3 formatos: puro, pontuado, com espaço em volta
--   razao_social  caixa e espaçamento inconsistentes
--   data_cadastro ISO e dd/MM/yyyy misturados
--   duplicidade   40 CNPJs com dois cliente_id diferentes
--
-- ARMADILHA: o Databricks SQL roda em ANSI mode. `to_date` sobre data
-- malformada NÃO retorna NULL — ela ABORTA a query com CAST_INVALID_INPUT.
-- Use sempre `try_to_date`. Esse detalhe derruba pipeline em produção.

CREATE OR REPLACE TABLE lakehouse_rotaperfume.silver.clientes
COMMENT 'Cadastro de clientes limpo e deduplicado. Uma linha por CNPJ real.'
AS
WITH limpo AS (
  SELECT
      CAST(cliente_id AS INT) AS cliente_id,

      -- CNPJ em três passos, e a ordem importa:
      --   trim          tira o espaço em volta (223 registros)
      --   regexp_replace tira ponto, barra e traço (1.111 registros)
      --   lpad          devolve os zeros à esquerda (309 registros)
      -- CNPJ NUNCA vira número. Número perde zero à esquerda e não volta.
      lpad(regexp_replace(trim(cnpj), '[^0-9]', ''), 14, '0') AS cnpj,

      -- Caixa e espaço duplo padronizados. initcap não é perfeito para "LTDA",
      -- mas é previsível — e previsível vale mais que perfeito numa chave de
      -- comparação.
      initcap(trim(regexp_replace(razao_social, '\\s+', ' '))) AS razao_social,

      trim(segmento) AS segmento,
      trim(cidade)   AS cidade,
      trim(uf)       AS uf,
      trim(bairro)   AS bairro,

      -- Dois formatos na mesma coluna. O coalesce tenta o ISO e, se falhar,
      -- tenta o brasileiro. try_ é o que impede a query de morrer no meio.
      coalesce(try_to_date(data_cadastro, 'yyyy-MM-dd'),
               try_to_date(data_cadastro, 'dd/MM/yyyy')) AS data_cadastro,

      (trim(ativo) = 'S') AS ativo
  FROM lakehouse_rotaperfume.bronze.clientes
),
-- Deduplicar NÃO é DISTINCT: o cliente_id é diferente, então o DISTINCT não
-- veria nada de errado. São 40 CNPJs recadastrados com id novo. A regra de
-- negócio: fica o cadastro MAIS ANTIGO, porque é para ele que os pedidos
-- antigos apontam.
ordenado AS (
  SELECT *,
         row_number() OVER (PARTITION BY cnpj ORDER BY data_cadastro, cliente_id) AS ordem,
         collect_list(cliente_id) OVER (PARTITION BY cnpj)                        AS ids_do_cnpj,
         count(*)                 OVER (PARTITION BY cnpj)                        AS cadastros_do_cnpj
  FROM limpo
)
SELECT
    cliente_id, cnpj, razao_social, segmento, cidade, uf, bairro,
    data_cadastro, ativo,
    -- Rastreabilidade: guardamos os ids descartados. Sem isso, um pedido do
    -- cadastro antigo vira órfão e ninguém sabe explicar por quê.
    array_except(ids_do_cnpj, array(cliente_id)) AS cliente_ids_duplicados,
    (cadastros_do_cnpj > 1)                      AS era_duplicado,
    current_timestamp()                          AS _processado_em,
    (SELECT count(*) FROM lakehouse_rotaperfume.bronze.clientes) AS _linhas_origem
FROM ordenado
WHERE ordem = 1;

-- O CONTRATO.
--
-- CONSTRAINT não é comentário: o Delta passa a RECUSAR qualquer escrita futura
-- que viole a regra. A regra deixa de ser do script que rodou hoje e passa a
-- ser da tabela, para sempre. Se o ALTER falhar, é porque a limpeza não fechou
-- — que é exatamente para isso que ele existe.
ALTER TABLE lakehouse_rotaperfume.silver.clientes
  ADD CONSTRAINT cnpj_com_14_digitos CHECK (length(cnpj) = 14);

ALTER TABLE lakehouse_rotaperfume.silver.clientes
  ADD CONSTRAINT data_cadastro_preenchida CHECK (data_cadastro IS NOT NULL);

ALTER TABLE lakehouse_rotaperfume.silver.clientes ALTER COLUMN cnpj
  COMMENT 'CNPJ normalizado para 14 dígitos, sem pontuação e com zeros à esquerda. Chave de negócio do cliente.';
ALTER TABLE lakehouse_rotaperfume.silver.clientes ALTER COLUMN cliente_ids_duplicados
  COMMENT 'Outros cliente_id encontrados com o mesmo CNPJ e descartados na deduplicação. Pedidos antigos podem apontar para eles.';
ALTER TABLE lakehouse_rotaperfume.silver.clientes ALTER COLUMN data_cadastro
  COMMENT 'Data de cadastro, resolvida a partir dos dois formatos que convivem na origem (ISO e dd/MM/yyyy).';
