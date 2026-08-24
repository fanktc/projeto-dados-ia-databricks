-- Noite 1 · A pergunta da noite, parte 1: qual foi nossa receita?
--
-- Rode com: python3 scripts/run_sql.py sql/n1_02_receita_mensal.sql

-- ============================================================================
-- 1a. A QUERY INGÊNUA — a que a gente escreveria sem olhar o dado.
--
-- Ela NÃO RODA. Vai falhar com CAST_INVALID_INPUT.
--
-- Motivo: na bronze toda coluna é texto, e 3.443 dos 28.729 pedidos (12%)
-- têm a data escrita como 15/10/2025 em vez de 2025-10-15. O date_trunc
-- tenta converter, não consegue, e derruba a query inteira.
--
-- Rode assim mesmo. O erro é a aula: o dado sujo não devolve resposta errada
-- em silêncio, ele para tudo. Pior seria se tivesse respondido.
-- ============================================================================

SELECT
    date_trunc('month', data_pedido) AS mes,
    COUNT(*)                         AS pedidos,
    ROUND(SUM(valor_total), 2)       AS receita
FROM rota_perfume.bronze.pedidos
WHERE status <> 'Cancelado'
GROUP BY 1
ORDER BY 1;

-- ============================================================================
-- 1b. A MESMA PERGUNTA, tratando o que o dado tem de errado.
--
-- try_to_date devolve NULL em vez de quebrar, então o coalesce pode tentar
-- os dois formatos em ordem: primeiro o ISO, depois o brasileiro.
--
-- O CAST para DECIMAL também importa: sem ele o Spark soma como número de
-- ponto flutuante e o total sai com centavos de ruído.
--
-- Esse coalesce é, na prática, um rascunho da camada silver. É isso que a
-- gente vai fazer direito amanhã — e para as 10 tabelas, não só para uma.
-- ============================================================================

SELECT
    date_trunc('month',
      coalesce(try_to_date(data_pedido, 'yyyy-MM-dd'),
               try_to_date(data_pedido, 'dd/MM/yyyy')))   AS mes,
    COUNT(*)                                              AS pedidos,
    ROUND(SUM(CAST(valor_total AS DECIMAL(18,2))), 2)     AS receita
FROM rota_perfume.bronze.pedidos
WHERE status <> 'Cancelado'
GROUP BY 1
ORDER BY 1;
