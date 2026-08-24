-- ============================================
-- EXEMPLO 01: SELECT — olhar o que existe
-- ============================================
-- Conceito: SELECT, FROM, LIMIT
-- Pergunta de negócio: o que a gente acabou de subir para o catálogo?
-- Conexão com a noite 2: esta é a bronze. Amanhã ela vira silver, limpa.
--
-- Primeiro dia de trabalho, ninguém te deu documentação. A primeira coisa
-- não é escrever a query bonita — é olhar o dado.

-- ============================================
-- 1. As primeiras linhas de pedidos
-- ============================================
-- LIMIT é obrigatório no primeiro olhar. São 28.729 pedidos: você não quer
-- todos eles na tela, quer entender o formato.

SELECT *
FROM rota_perfume.bronze.pedidos
LIMIT 10;


-- ============================================
-- 2. Repare em algo estranho
-- ============================================
-- Todas as colunas são texto, inclusive valor_total e data_pedido.
-- Isso é de propósito: a bronze guarda o dado como veio, sem interpretar.
-- Se o Spark tivesse adivinhado os tipos, ele teria estragado as datas.

DESCRIBE TABLE rota_perfume.bronze.pedidos;


-- ============================================
-- 3. Quantas linhas tem cada tabela?
-- ============================================
-- COUNT(*) conta linhas. É a pergunta mais básica e a mais esquecida.

SELECT COUNT(*) AS total_pedidos FROM rota_perfume.bronze.pedidos;


-- ============================================
-- 4. Escolher só as colunas que interessam
-- ============================================
-- SELECT * serve para explorar. Em query de verdade, peça o que precisa:
-- é mais rápido e deixa claro para quem lê o que importa ali.

SELECT pedido_id, cliente_id, data_pedido, canal, status, valor_total
FROM rota_perfume.bronze.pedidos
LIMIT 10;
