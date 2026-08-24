-- ============================================
-- EXEMPLO 02: ORDER BY e DISTINCT — achar o extremo
-- ============================================
-- Conceito: ORDER BY, DESC, DISTINCT
-- Pergunta de negócio: qual foi o maior pedido? Que canais existem?
--
-- Depois de saber o que existe, o analista procura o extremo. É onde mora
-- tanto a informação boa quanto o erro de cadastro.

-- ============================================
-- 1. Os maiores pedidos
-- ============================================
-- CAST é necessário: valor_total é texto na bronze, e texto ordena errado
-- ('9' vem depois de '10' na ordem alfabética).

SELECT pedido_id, data_pedido, canal, valor_total
FROM lakehouse_rotaperfume.bronze.pedidos
ORDER BY CAST(valor_total AS DECIMAL(18,2)) DESC
LIMIT 10;


-- ============================================
-- 2. Prova de que o CAST importa
-- ============================================
-- Rode e compare com a anterior. Sem CAST, o "maior" pedido é o que começa
-- com o dígito mais alto, não o de maior valor.

SELECT pedido_id, valor_total
FROM lakehouse_rotaperfume.bronze.pedidos
ORDER BY valor_total DESC
LIMIT 10;


-- ============================================
-- 3. Que valores existem numa coluna?
-- ============================================
-- DISTINCT antes de filtrar. Você precisa saber o que tem para escrever o
-- WHERE certo — e é assim que se descobre que existe 'Cancelado'.

SELECT DISTINCT status FROM lakehouse_rotaperfume.bronze.pedidos;

SELECT DISTINCT canal FROM lakehouse_rotaperfume.bronze.pedidos;


-- ============================================
-- 4. Contando cada valor
-- ============================================
-- Melhor que DISTINCT puro: quantas vezes cada um aparece.

SELECT status, COUNT(*) AS pedidos
FROM lakehouse_rotaperfume.bronze.pedidos
GROUP BY status
ORDER BY pedidos DESC;
