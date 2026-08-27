-- Os quatro números que o diretor olha antes de qualquer tabela.
-- A fila da semana, a métrica do modelo que a gerou e o retorno já registrado.
WITH fila AS (
  SELECT COUNT(*)                        AS contatos,
         COUNT(DISTINCT vendedor)        AS vendedores,
         SUM(score * ticket_medio)       AS receita_esperada,
         MAX(_referencia)                AS referencia
  FROM   lakehouse_rotaperfume.gold.fila_semanal
),
modelo AS (
  SELECT acertos_top200, lift_top200, taxa_base, auc, versao
  FROM   lakehouse_rotaperfume.gold.modelo_metricas
  QUALIFY ROW_NUMBER() OVER (ORDER BY versao DESC) = 1
),
retorno AS (
  SELECT COUNT(*)                                  AS ligacoes_registradas,
         COUNT_IF(status = 'vendeu')               AS vendas
  FROM   lakehouse_rotaperfume.gold.retorno_ligacao
)
SELECT fila.contatos,
       fila.vendedores,
       fila.receita_esperada,
       fila.referencia,
       modelo.acertos_top200,
       modelo.lift_top200,
       modelo.taxa_base,
       modelo.auc,
       modelo.versao,
       retorno.ligacoes_registradas,
       retorno.vendas
FROM fila, modelo, retorno
