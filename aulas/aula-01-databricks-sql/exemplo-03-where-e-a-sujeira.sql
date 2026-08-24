-- ============================================
-- EXEMPLO 03: WHERE — filtrar, e achar a sujeira
-- ============================================
-- Conceito: WHERE, LIKE, IS NULL, operadores de comparação
-- Pergunta de negócio: quais pedidos contam como receita?
-- Conexão com a noite 2: tudo que este exemplo acha é o que a silver conserta.
--
-- Este é o exemplo mais importante do dia. O filtro errado não dá erro:
-- ele dá um número menor, em silêncio, e ninguém percebe.

-- ============================================
-- 1. Pedido cancelado não é receita
-- ============================================

SELECT COUNT(*) AS cancelados
FROM rota_perfume.bronze.pedidos
WHERE status = 'Cancelado';


-- ============================================
-- 2. A primeira armadilha: o cancelado vem com valor zerado
-- ============================================
-- Repare: dá na mesma somar com ou sem eles, porque valem 0. Mas a CONTAGEM
-- muda — e ticket médio é receita dividida por contagem.

SELECT
    status = 'Cancelado'                               AS cancelado,
    COUNT(*)                                           AS pedidos,
    ROUND(SUM(CAST(valor_total AS DECIMAL(18,2))), 2)  AS receita
FROM rota_perfume.bronze.pedidos
GROUP BY 1;


-- ============================================
-- 3. A segunda armadilha: a data vem em dois formatos
-- ============================================
-- LIKE '%/%' acha as datas escritas como 15/10/2025 em vez de 2025-10-15.
-- São 3.443 pedidos, 12% da base.

SELECT COUNT(*) AS datas_em_formato_brasileiro
FROM rota_perfume.bronze.pedidos
WHERE data_pedido LIKE '%/%';

-- Veja alguns:
SELECT pedido_id, data_pedido, valor_total
FROM rota_perfume.bronze.pedidos
WHERE data_pedido LIKE '%/%'
LIMIT 5;


-- ============================================
-- 4. A terceira armadilha: o CNPJ tem três formatos
-- ============================================
-- Puro, pontuado e com espaço em volta. O mesmo cliente, escrito de três
-- jeitos, vira três clientes em qualquer contagem.

SELECT
    COUNT(*)                                          AS clientes,
    COUNT(*) FILTER (WHERE cnpj LIKE '%.%')           AS pontuado,
    COUNT(*) FILTER (WHERE cnpj <> trim(cnpj))        AS com_espaco,
    COUNT(DISTINCT cnpj)                              AS cnpj_distintos,
    COUNT(DISTINCT regexp_replace(trim(cnpj), '[^0-9]', '')) AS cnpj_de_verdade
FROM rota_perfume.bronze.clientes;

-- A diferença entre as duas últimas colunas é o tamanho do problema.


-- ============================================
-- 5. A quarta armadilha: devolução é quantidade negativa
-- ============================================

SELECT COUNT(*) AS itens_devolvidos
FROM rota_perfume.bronze.itens_pedido
WHERE CAST(quantidade AS INT) < 0;
