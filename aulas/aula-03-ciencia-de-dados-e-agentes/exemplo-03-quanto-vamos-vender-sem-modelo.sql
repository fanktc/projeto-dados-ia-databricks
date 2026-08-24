-- ============================================
-- EXEMPLO 03: Quanto vamos vender?
-- ============================================
-- Conceito: índice sazonal, nível dessazonalizado, teste retroativo
-- Pergunta de negócio: quanto planejar de compra e de caixa?
-- Conexão: com 2 ciclos de histórico, entregue faixa e não número cheio
--
-- Rode com:
--   python3 scripts/run_sql.py aulas/aula-03-ciencia-de-dados-e-agentes/exemplo-03-quanto-vamos-vender-sem-modelo.sql

-- ----------------------------------------------------------------------------
-- 3.1 · O PADRÃO: quanto cada mês do ano costuma fazer.
--
-- Índice 1,00 = mês médio. Acima de 1, o mês puxa; abaixo, ele afunda.
-- ----------------------------------------------------------------------------

WITH mensal AS (
    SELECT
        date_trunc('month',
          coalesce(try_to_date(data_pedido, 'yyyy-MM-dd'),
                   try_to_date(data_pedido, 'dd/MM/yyyy')))    AS mes,
        SUM(CAST(valor_total AS DECIMAL(18,2)))                AS receita
    FROM rota_perfume.bronze.pedidos
    WHERE status <> 'Cancelado'
    GROUP BY 1
    HAVING date_trunc('month',
             coalesce(try_to_date(data_pedido, 'yyyy-MM-dd'),
                      try_to_date(data_pedido, 'dd/MM/yyyy'))) >= DATE'2024-11-01'
)
SELECT
    month(mes)                                              AS mes_do_ano,
    COUNT(*)                                                AS anos_observados,
    ROUND(AVG(receita), 2)                                  AS receita_media,
    ROUND(AVG(receita) / (SELECT AVG(receita) FROM mensal), 2) AS indice_sazonal,
    CASE
        WHEN AVG(receita) / (SELECT AVG(receita) FROM mensal) >= 1.25 THEN 'PICO'
        WHEN AVG(receita) / (SELECT AVG(receita) FROM mensal) <= 0.75 THEN 'vale'
        ELSE ''
    END                                                     AS marca
FROM mensal
GROUP BY 1
ORDER BY indice_sazonal DESC;

-- ----------------------------------------------------------------------------
-- 3.2 · O MÉTODO ACERTA? Prevendo agosto/2026 sem olhar para ele.
--
-- Usa só o que se sabia até 31/07/2026 e compara com o que de fato aconteceu.
-- Um número de previsão sem erro medido não serve para decidir nada.
-- ----------------------------------------------------------------------------

WITH mensal AS (
    SELECT date_trunc('month',
             coalesce(try_to_date(data_pedido, 'yyyy-MM-dd'),
                      try_to_date(data_pedido, 'dd/MM/yyyy')))  AS mes,
           SUM(CAST(valor_total AS DECIMAL(18,2)))              AS receita
    FROM rota_perfume.bronze.pedidos
    WHERE status <> 'Cancelado'
    GROUP BY 1
),
treino AS (   -- só o passado conhecido em 31/07/2026
    SELECT * FROM mensal WHERE mes BETWEEN DATE'2024-11-01' AND DATE'2026-07-01'
),
indice AS (
    SELECT month(mes) AS mes_do_ano,
           AVG(receita) / (SELECT AVG(receita) FROM treino) AS fator
    FROM treino GROUP BY 1
),
nivel AS (    -- onde o negócio estava nos 3 meses anteriores, já sem sazonalidade
    SELECT AVG(t.receita / i.fator) AS base
    FROM treino t JOIN indice i ON i.mes_do_ano = month(t.mes)
    WHERE t.mes >= DATE'2026-05-01'
)
SELECT
    'agosto/2026'                                                   AS mes,
    ROUND((SELECT base FROM nivel) * (SELECT fator FROM indice WHERE mes_do_ano = 8), 2) AS previsto,
    ROUND((SELECT receita FROM mensal WHERE mes = DATE'2026-08-01'), 2)                  AS realizado,
    ROUND(100 * abs((SELECT base FROM nivel) * (SELECT fator FROM indice WHERE mes_do_ano = 8)
                    - (SELECT receita FROM mensal WHERE mes = DATE'2026-08-01'))
              / (SELECT receita FROM mensal WHERE mes = DATE'2026-08-01'), 1)            AS erro_pct;

-- ----------------------------------------------------------------------------
-- 3.3 · A RESPOSTA: os próximos três meses.
--
-- Setembro, outubro e novembro de 2026 — e outubro é o mês que decide o ano.
--
-- Sobre a margem de mais ou menos 15%: ela NÃO vem do erro de 1,2% medido em
-- 3.2. Um único mês testado não prova que o método erra 1,2% sempre — prova
-- que ele acertou uma vez. A margem vem de outra coisa: são só 2 ciclos
-- anuais de histórico, e outubro só foi observado duas vezes.
--
-- Prometer o número cheio para a diretoria é o erro clássico. Entregue a
-- faixa, e diga em cima de quantas observações ela foi construída.
-- ----------------------------------------------------------------------------

WITH mensal AS (
    SELECT date_trunc('month',
             coalesce(try_to_date(data_pedido, 'yyyy-MM-dd'),
                      try_to_date(data_pedido, 'dd/MM/yyyy')))  AS mes,
           SUM(CAST(valor_total AS DECIMAL(18,2)))              AS receita
    FROM rota_perfume.bronze.pedidos
    WHERE status <> 'Cancelado'
    GROUP BY 1
    HAVING date_trunc('month',
             coalesce(try_to_date(data_pedido, 'yyyy-MM-dd'),
                      try_to_date(data_pedido, 'dd/MM/yyyy'))) >= DATE'2024-11-01'
),
indice AS (
    SELECT month(mes) AS mes_do_ano,
           AVG(receita) / (SELECT AVG(receita) FROM mensal) AS fator
    FROM mensal GROUP BY 1
),
nivel AS (
    SELECT AVG(m.receita / i.fator) AS base
    FROM mensal m JOIN indice i ON i.mes_do_ano = month(m.mes)
    WHERE m.mes >= DATE'2026-06-01'
),
previsao AS (
    SELECT 'set/2026' AS mes, 9 AS n UNION ALL
    SELECT 'out/2026', 10 UNION ALL
    SELECT 'nov/2026', 11
)
SELECT
    p.mes,
    ROUND(i.fator, 2)                                    AS indice_sazonal,
    ROUND((SELECT base FROM nivel) * i.fator, 2)         AS previsto,
    -- margem honesta: o erro medido em 3.2 aplicado para os dois lados
    ROUND((SELECT base FROM nivel) * i.fator * 0.85, 2)  AS cenario_baixo,
    ROUND((SELECT base FROM nivel) * i.fator * 1.15, 2)  AS cenario_alto
FROM previsao p
JOIN indice i ON i.mes_do_ano = p.n
ORDER BY p.n;
