-- ============================================
-- EXEMPLO 05: JOIN — quem são os melhores clientes
-- ============================================
-- Conceito: JOIN, GROUP BY por chave certa, COUNT(DISTINCT)
-- Pergunta de negócio: quem sustenta o faturamento?
-- Conexão com a aula 02: a deduplicação por CNPJ resolve o que sobra aqui
--
-- Rode com:
--   python3 scripts/run_sql.py aulas/aula-01-databricks-sql/exemplo-05-join-melhores-clientes.sql

-- ============================================================================
-- 2a. Top 10 clientes agrupando por NOME.
--
-- Essa query roda e devolve uma lista bonita. O problema é que ela está errada.
--
-- Razão social não é chave. Existem clientes diferentes com o mesmo nome, e
-- existem os ~40 duplicados de propósito (mesmo CNPJ, cadastro repetido).
-- Agrupar por nome funde todos eles numa linha só e inventa um cliente gigante
-- que não existe.
-- ============================================================================

SELECT
    c.razao_social,
    c.segmento,
    COUNT(DISTINCT p.pedido_id)                         AS pedidos,
    ROUND(SUM(CAST(p.valor_total AS DECIMAL(18,2))), 2) AS receita
FROM rota_perfume.bronze.pedidos p
JOIN rota_perfume.bronze.clientes c
  ON c.cliente_id = p.cliente_id
WHERE p.status <> 'Cancelado'
GROUP BY 1, 2
ORDER BY receita DESC
LIMIT 10;

-- ============================================================================
-- 2b. A mesma lista agrupando por cliente_id, que é a chave de verdade.
--
-- Compare o topo das duas listas. O "melhor cliente" da query anterior
-- desaparece: ele era vários clientes somados por engano.
--
-- Repare que isso ainda não resolve o problema de verdade — os 40 duplicados
-- têm cliente_id DIFERENTE e o mesmo CNPJ, então continuam contados em
-- dobro aqui. Só a deduplicação por CNPJ resolve, e ela é a noite 2.
-- ============================================================================

SELECT
    p.cliente_id,
    max(c.razao_social)                                 AS razao_social,
    max(c.segmento)                                     AS segmento,
    COUNT(DISTINCT p.pedido_id)                         AS pedidos,
    ROUND(SUM(CAST(p.valor_total AS DECIMAL(18,2))), 2) AS receita
FROM rota_perfume.bronze.pedidos p
JOIN rota_perfume.bronze.clientes c
  ON c.cliente_id = p.cliente_id
WHERE p.status <> 'Cancelado'
GROUP BY 1
ORDER BY receita DESC
LIMIT 10;

-- ============================================================================
-- 2c. A prova de que o problema existe: quantos nomes escondem mais de um cliente?
-- ============================================================================

SELECT
    COUNT(DISTINCT cliente_id)   AS clientes_distintos,
    COUNT(DISTINCT razao_social) AS nomes_distintos,
    COUNT(DISTINCT cliente_id) - COUNT(DISTINCT razao_social) AS clientes_que_somem_ao_agrupar_por_nome
FROM rota_perfume.bronze.clientes;
