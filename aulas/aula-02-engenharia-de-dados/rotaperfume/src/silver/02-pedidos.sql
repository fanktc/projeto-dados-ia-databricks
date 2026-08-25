-- Silver · pedidos
--
-- A tabela que carrega o número que a diretoria olha. Três decisões aqui:
--
--   data_pedido  12% vêm em dd/MM/yyyy — foi essa coluna que quebrou a query
--                da noite 1, ao vivo, na frente de todo mundo
--   valor_total  é texto na bronze, vira DECIMAL aqui (nunca FLOAT: dinheiro
--                em ponto flutuante é como fica R$ 0,01 de diferença no
--                fechamento do mês)
--   cancelado    o ERP zera o valor e não avisa. Uma flag explícita vale mais
--                que confiar num valor zerado, porque pedido de R$ 0,00 pode
--                existir por outros motivos

CREATE OR REPLACE TABLE lakehouse_rotaperfume.silver.pedidos
COMMENT 'Cabeçalho do pedido, com data resolvida, valor tipado e cancelamento explícito.'
AS
SELECT
    CAST(pedido_id   AS INT) AS pedido_id,
    CAST(cliente_id  AS INT) AS cliente_id,
    CAST(vendedor_id AS INT) AS vendedor_id,

    coalesce(try_to_date(data_pedido, 'yyyy-MM-dd'),
             try_to_date(data_pedido, 'dd/MM/yyyy')) AS data_pedido,

    trim(canal)  AS canal,
    trim(status) AS status,

    CAST(valor_total AS DECIMAL(18,2)) AS valor_total,
    (trim(status) = 'Cancelado')       AS cancelado,

    -- valor_liquido é o que conta como receita. Separar as duas colunas deixa
    -- explícito o que foi vendido e o que foi cancelado, sem ninguém precisar
    -- lembrar de filtrar status na hora de somar.
    CASE WHEN trim(status) = 'Cancelado' THEN CAST(0 AS DECIMAL(18,2))
         ELSE CAST(valor_total AS DECIMAL(18,2)) END AS valor_liquido,

    year(coalesce(try_to_date(data_pedido, 'yyyy-MM-dd'),
                  try_to_date(data_pedido, 'dd/MM/yyyy')))  AS ano,
    month(coalesce(try_to_date(data_pedido, 'yyyy-MM-dd'),
                   try_to_date(data_pedido, 'dd/MM/yyyy'))) AS mes,

    current_timestamp() AS _processado_em,
    (SELECT count(*) FROM lakehouse_rotaperfume.bronze.pedidos) AS _linhas_origem
FROM lakehouse_rotaperfume.bronze.pedidos;

ALTER TABLE lakehouse_rotaperfume.silver.pedidos
  ADD CONSTRAINT data_pedido_preenchida CHECK (data_pedido IS NOT NULL);

-- Esta constraint nasceu como `valor_liquido >= 0` e FALHOU em 135 pedidos.
-- A investigação mostrou que os 135 têm item devolvido: valor negativo ali é
-- pedido cujo saldo virou devolução — negócio legítimo, não sujeira. A regra
-- errada era a nossa, não o dado. É para isso que a constraint serve: ela
-- transforma uma suposição em pergunta antes de ela virar número no dashboard.
ALTER TABLE lakehouse_rotaperfume.silver.pedidos
  ADD CONSTRAINT cancelado_tem_valor_zero CHECK (NOT cancelado OR valor_liquido = 0);

ALTER TABLE lakehouse_rotaperfume.silver.pedidos ALTER COLUMN valor_liquido
  COMMENT 'Valor que conta como receita: zero quando o pedido foi cancelado, valor_total caso contrário.';
ALTER TABLE lakehouse_rotaperfume.silver.pedidos ALTER COLUMN cancelado
  COMMENT 'Flag explícita de cancelamento. O ERP zera o valor sem sinalizar — não confie no valor zerado.';
ALTER TABLE lakehouse_rotaperfume.silver.pedidos ALTER COLUMN data_pedido
  COMMENT 'Data do pedido, resolvida dos dois formatos da origem. 12% vinham em dd/MM/yyyy.';
