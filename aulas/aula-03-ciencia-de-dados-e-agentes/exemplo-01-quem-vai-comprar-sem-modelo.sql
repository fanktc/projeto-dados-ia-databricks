-- ============================================
-- EXEMPLO 01: Quem vai comprar?
-- ============================================
-- Conceito: LAG, median, CTE encadeada, validação retroativa
-- Pergunta de negócio: para quem o vendedor liga na segunda-feira?
-- Conexão: esta régua é a LINHA DE BASE que o modelo do exemplo 05 precisa bater
--
-- Repare no tamanho desta query comparada com a mesma pergunta feita sobre a
-- bronze na noite 1: sem CAST, sem coalesce de data, sem try_to_date. A
-- camada silver pagou o imposto uma vez para todo mundo.
--
-- A régua: cada cliente tem um ritmo. Última compra + ritmo = próxima compra.
--
-- Rode com:
--   python3 scripts/run_sql.py aulas/aula-03-ciencia-de-dados-e-agentes/exemplo-01-quem-vai-comprar-sem-modelo.sql

-- ----------------------------------------------------------------------------
-- 1.1 · A RESPOSTA: quem deve comprar nos próximos 30 dias.
-- Ordenado por valor esperado: o vendedor tem tempo para 20 ligações, e elas
-- devem ser as 20 que mais valem.
-- ----------------------------------------------------------------------------

WITH ritmo AS (
    SELECT
        cliente_id,
        COUNT(*)                                    AS pedidos,
        AVG(valor_liquido)                          AS ticket_medio,
        MAX(data_pedido)                            AS ultima_compra,
        datediff(DATE'2026-08-31', MAX(data_pedido)) AS dias_parado,
        median(datediff(data_pedido, anterior))     AS ritmo_dias
    FROM (
        SELECT cliente_id, data_pedido, valor_liquido,
               lag(data_pedido) OVER (PARTITION BY cliente_id ORDER BY data_pedido) AS anterior
        FROM rota_perfume.silver.pedidos
        WHERE NOT cancelado
    )
    GROUP BY cliente_id
    HAVING COUNT(*) >= 3 AND median(datediff(data_pedido, anterior)) IS NOT NULL
),
visitas AS (
    SELECT cliente_id,
           COUNT(*) FILTER (WHERE data_visita >= DATE'2026-06-01') AS visitas_90d
    FROM rota_perfume.silver.visitas GROUP BY cliente_id
),
funil AS (
    SELECT cliente_id, COUNT(*) AS oportunidades_abertas
    FROM rota_perfume.silver.oportunidades WHERE aberta GROUP BY cliente_id
)
SELECT
    r.cliente_id,
    c.razao_social                                          AS cliente,
    c.segmento,
    c.cidade,
    r.ultima_compra,
    r.ritmo_dias                                            AS compra_a_cada,
    date_add(r.ultima_compra, CAST(r.ritmo_dias AS INT))    AS proxima_compra_prevista,
    ROUND(r.ticket_medio, 2)                                AS valor_esperado,
    coalesce(v.visitas_90d, 0)                              AS visitas_90d,
    coalesce(f.oportunidades_abertas, 0)                    AS oport_abertas,
    -- o vendedor precisa saber o que dizer quando ligar
    CASE
        WHEN r.dias_parado > r.ritmo_dias             THEN 'Já passou do ponto de recompra'
        WHEN coalesce(f.oportunidades_abertas, 0) > 0 THEN 'Tem proposta aberta no funil'
        WHEN coalesce(v.visitas_90d, 0) > 0           THEN 'Visitado nos últimos 90 dias'
        ELSE                                               'Entrando na janela de compra'
    END                                                     AS motivo
FROM ritmo r
JOIN rota_perfume.gold.dim_cliente c ON c.cliente_id = r.cliente_id
LEFT JOIN visitas v ON v.cliente_id = r.cliente_id
LEFT JOIN funil   f ON f.cliente_id = r.cliente_id
WHERE date_add(r.ultima_compra, CAST(r.ritmo_dias AS INT))
        BETWEEN DATE'2026-08-31' AND date_add(DATE'2026-08-31', 30)
ORDER BY valor_esperado DESC
LIMIT 20;

-- ----------------------------------------------------------------------------
-- 1.2 · O TAMANHO DA OPORTUNIDADE.
-- ----------------------------------------------------------------------------

WITH ritmo AS (
    SELECT cliente_id, AVG(valor_liquido) AS ticket_medio, MAX(data_pedido) AS ultima_compra,
           median(datediff(data_pedido, anterior)) AS ritmo_dias
    FROM (SELECT cliente_id, data_pedido, valor_liquido,
                 lag(data_pedido) OVER (PARTITION BY cliente_id ORDER BY data_pedido) AS anterior
          FROM rota_perfume.silver.pedidos WHERE NOT cancelado)
    GROUP BY cliente_id
    HAVING COUNT(*) >= 3 AND median(datediff(data_pedido, anterior)) IS NOT NULL
)
SELECT
    COUNT(*)                        AS clientes_na_janela,
    ROUND(SUM(ticket_medio), 2)     AS receita_esperada_30_dias,
    ROUND(AVG(ticket_medio), 2)     AS ticket_medio_da_lista
FROM ritmo
WHERE date_add(ultima_compra, CAST(ritmo_dias AS INT))
        BETWEEN DATE'2026-08-31' AND date_add(DATE'2026-08-31', 30);

-- ----------------------------------------------------------------------------
-- 1.3 · A RÉGUA ACERTA? O teste que ninguém faz.
--
-- Volta no tempo: usa só o que se sabia até 31/07/2026, monta a lista com a
-- mesma regra, e confere quem realmente comprou em agosto.
--
-- Sem esse teste, a lista é palpite com cara de relatório. E é este número
-- que o modelo do exemplo 05 vai ter de bater.
-- ----------------------------------------------------------------------------

WITH ate_julho AS (
    SELECT cliente_id, data_pedido
    FROM rota_perfume.silver.pedidos
    WHERE NOT cancelado AND data_pedido <= DATE'2026-07-31'
),
ritmo AS (
    SELECT cliente_id, MAX(data_pedido) AS ultima_compra,
           median(datediff(data_pedido, anterior)) AS ritmo_dias
    FROM (SELECT cliente_id, data_pedido,
                 lag(data_pedido) OVER (PARTITION BY cliente_id ORDER BY data_pedido) AS anterior
          FROM ate_julho)
    GROUP BY cliente_id
    HAVING COUNT(*) >= 3 AND median(datediff(data_pedido, anterior)) IS NOT NULL
),
previstos AS (
    SELECT cliente_id FROM ritmo
    WHERE date_add(ultima_compra, CAST(ritmo_dias AS INT))
            BETWEEN DATE'2026-07-31' AND DATE'2026-08-31'
),
compraram AS (
    SELECT DISTINCT cliente_id FROM rota_perfume.silver.pedidos
    WHERE NOT cancelado
      AND data_pedido > DATE'2026-07-31' AND data_pedido <= DATE'2026-08-31'
)
SELECT
    (SELECT COUNT(*) FROM previstos)                                       AS lista_previa,
    (SELECT COUNT(*) FROM previstos JOIN compraram USING (cliente_id))     AS acertou,
    ROUND(100.0 * (SELECT COUNT(*) FROM previstos JOIN compraram USING (cliente_id))
                / (SELECT COUNT(*) FROM previstos), 1)                     AS precisao_pct,
    -- linha de base: e se ligássemos para todo mundo, sem régua nenhuma?
    ROUND(100.0 * (SELECT COUNT(*) FROM compraram JOIN ritmo USING (cliente_id))
                / (SELECT COUNT(*) FROM ritmo), 1)                         AS taxa_sem_regua;
