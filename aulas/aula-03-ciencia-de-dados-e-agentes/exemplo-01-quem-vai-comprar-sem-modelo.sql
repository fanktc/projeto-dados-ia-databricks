-- ============================================
-- EXEMPLO 01: Quem vai comprar?
-- ============================================
-- Conceito: LAG, median, CTE encadeada, validação retroativa
-- Pergunta de negócio: para quem o vendedor liga na segunda-feira?
-- Conexão: esta régua é a LINHA DE BASE que o modelo precisa bater
--
-- Rode com:
--   python3 scripts/run_sql.py aulas/aula-03-ciencia-de-dados-e-agentes/exemplo-01-quem-vai-comprar-sem-modelo.sql

-- ----------------------------------------------------------------------------
-- 1.1 · A RESPOSTA: quem deve comprar nos próximos 30 dias.
--
-- Ordenado por valor esperado, não por probabilidade. O vendedor tem tempo
-- para 20 ligações, e elas devem ser as 20 que mais valem.
-- ----------------------------------------------------------------------------

WITH pedidos AS (
    SELECT
        CAST(cliente_id AS INT)                              AS cliente_id,
        coalesce(try_to_date(data_pedido, 'yyyy-MM-dd'),
                 try_to_date(data_pedido, 'dd/MM/yyyy'))     AS data_pedido,
        CAST(valor_total AS DECIMAL(18,2))                   AS valor_total
    FROM rota_perfume.bronze.pedidos
    WHERE status <> 'Cancelado'
),
perfil AS (
    SELECT
        cliente_id,
        COUNT(*)                                     AS pedidos,
        AVG(valor_total)                             AS ticket_medio,
        SUM(valor_total)                             AS receita_historica,
        MAX(data_pedido)                             AS ultima_compra,
        datediff(DATE'2026-08-31', MAX(data_pedido)) AS dias_parado
    FROM pedidos
    GROUP BY cliente_id
    HAVING COUNT(*) >= 3
),
ritmo AS (
    SELECT cliente_id, median(datediff(data_pedido, anterior)) AS ritmo_dias
    FROM (
        SELECT cliente_id, data_pedido,
               lag(data_pedido) OVER (PARTITION BY cliente_id ORDER BY data_pedido) AS anterior
        FROM pedidos
    )
    WHERE anterior IS NOT NULL
    GROUP BY cliente_id
),
-- Sinal do CRM: visita recente é intenção. O ERP sozinho não enxerga isso.
visitas AS (
    SELECT
        CAST(cliente_id AS INT) AS cliente_id,
        COUNT(*) FILTER (
            WHERE try_to_date(data_visita, 'yyyy-MM-dd') >= DATE'2026-06-01'
        ) AS visitas_90d,
        MAX(CASE WHEN resultado = 'Pedido realizado' THEN 1 ELSE 0 END) AS ja_converteu
    FROM rota_perfume.bronze.visitas
    GROUP BY 1
),
funil AS (
    SELECT CAST(cliente_id AS INT) AS cliente_id,
           COUNT(*) AS oportunidades_abertas,
           SUM(CAST(valor_estimado AS DECIMAL(18,2))) AS valor_no_funil
    FROM rota_perfume.bronze.oportunidades
    WHERE etapa NOT IN ('Fechado ganho', 'Fechado perdido')
    GROUP BY 1
)
SELECT
    p.cliente_id,
    initcap(trim(c.razao_social))                              AS cliente,
    c.segmento,
    c.cidade,
    p.ultima_compra,
    r.ritmo_dias                                               AS compra_a_cada,
    date_add(p.ultima_compra, CAST(r.ritmo_dias AS INT))       AS proxima_compra_prevista,
    ROUND(p.ticket_medio, 2)                                   AS valor_esperado,
    coalesce(v.visitas_90d, 0)                                 AS visitas_90d,
    coalesce(f.oportunidades_abertas, 0)                       AS oport_abertas,
    -- Um motivo em texto: o vendedor precisa saber o que dizer ao ligar.
    CASE
        WHEN p.dias_parado > r.ritmo_dias      THEN 'Já passou do ponto de recompra'
        WHEN coalesce(f.oportunidades_abertas, 0) > 0 THEN 'Tem proposta aberta no funil'
        WHEN coalesce(v.visitas_90d, 0) > 0    THEN 'Visitado nos últimos 90 dias'
        ELSE                                        'Está entrando na janela de compra'
    END                                                        AS motivo
FROM perfil p
JOIN ritmo r ON r.cliente_id = p.cliente_id
JOIN rota_perfume.bronze.clientes c ON CAST(c.cliente_id AS INT) = p.cliente_id
LEFT JOIN visitas v ON v.cliente_id = p.cliente_id
LEFT JOIN funil   f ON f.cliente_id = p.cliente_id
-- a próxima compra prevista cai dentro dos próximos 30 dias
WHERE date_add(p.ultima_compra, CAST(r.ritmo_dias AS INT))
        BETWEEN DATE'2026-08-31' AND date_add(DATE'2026-08-31', 30)
ORDER BY valor_esperado DESC
LIMIT 20;

-- ----------------------------------------------------------------------------
-- 1.2 · O TAMANHO DA OPORTUNIDADE.
-- ----------------------------------------------------------------------------

WITH pedidos AS (
    SELECT CAST(cliente_id AS INT) AS cliente_id,
           coalesce(try_to_date(data_pedido, 'yyyy-MM-dd'),
                    try_to_date(data_pedido, 'dd/MM/yyyy')) AS data_pedido,
           CAST(valor_total AS DECIMAL(18,2)) AS valor_total
    FROM rota_perfume.bronze.pedidos WHERE status <> 'Cancelado'
),
perfil AS (
    SELECT cliente_id, AVG(valor_total) AS ticket_medio, MAX(data_pedido) AS ultima_compra
    FROM pedidos GROUP BY cliente_id HAVING COUNT(*) >= 3
),
ritmo AS (
    SELECT cliente_id, median(datediff(data_pedido, anterior)) AS ritmo_dias
    FROM (SELECT cliente_id, data_pedido,
                 lag(data_pedido) OVER (PARTITION BY cliente_id ORDER BY data_pedido) AS anterior
          FROM pedidos)
    WHERE anterior IS NOT NULL GROUP BY cliente_id
)
SELECT
    COUNT(*)                                    AS clientes_na_janela,
    ROUND(SUM(p.ticket_medio), 2)               AS receita_esperada_30_dias,
    ROUND(AVG(p.ticket_medio), 2)               AS ticket_medio_da_lista
FROM perfil p JOIN ritmo r ON r.cliente_id = p.cliente_id
WHERE date_add(p.ultima_compra, CAST(r.ritmo_dias AS INT))
        BETWEEN DATE'2026-08-31' AND date_add(DATE'2026-08-31', 30);

-- ----------------------------------------------------------------------------
-- 1.3 · A RÉGUA ACERTA? O teste que ninguém faz.
--
-- Volta no tempo: usa só o que se sabia até 31/07/2026, monta a lista com a
-- mesma regra, e confere quem realmente comprou em agosto.
--
-- Sem esse teste, a lista é palpite com cara de relatório.
-- ----------------------------------------------------------------------------

WITH pedidos AS (
    SELECT CAST(cliente_id AS INT) AS cliente_id,
           coalesce(try_to_date(data_pedido, 'yyyy-MM-dd'),
                    try_to_date(data_pedido, 'dd/MM/yyyy')) AS data_pedido,
           CAST(valor_total AS DECIMAL(18,2)) AS valor_total
    FROM rota_perfume.bronze.pedidos WHERE status <> 'Cancelado'
),
ate_julho AS (   -- tudo que se sabia no dia 31/07/2026
    SELECT * FROM pedidos WHERE data_pedido <= DATE'2026-07-31'
),
perfil AS (
    SELECT cliente_id, MAX(data_pedido) AS ultima_compra
    FROM ate_julho GROUP BY cliente_id HAVING COUNT(*) >= 3
),
ritmo AS (
    SELECT cliente_id, median(datediff(data_pedido, anterior)) AS ritmo_dias
    FROM (SELECT cliente_id, data_pedido,
                 lag(data_pedido) OVER (PARTITION BY cliente_id ORDER BY data_pedido) AS anterior
          FROM ate_julho)
    WHERE anterior IS NOT NULL GROUP BY cliente_id
),
previstos AS (   -- a lista que a regra teria gerado em 31/07
    SELECT p.cliente_id
    FROM perfil p JOIN ritmo r ON r.cliente_id = p.cliente_id
    WHERE date_add(p.ultima_compra, CAST(r.ritmo_dias AS INT))
            BETWEEN DATE'2026-07-31' AND DATE'2026-08-31'
),
compraram AS (   -- quem de fato comprou em agosto
    SELECT DISTINCT cliente_id FROM pedidos
    WHERE data_pedido > DATE'2026-07-31' AND data_pedido <= DATE'2026-08-31'
),
universo AS (SELECT cliente_id FROM perfil)
SELECT
    (SELECT COUNT(*) FROM previstos)                                        AS lista_previa,
    (SELECT COUNT(*) FROM previstos p JOIN compraram c USING (cliente_id))  AS acertou,
    ROUND(100.0 * (SELECT COUNT(*) FROM previstos p JOIN compraram c USING (cliente_id))
                / (SELECT COUNT(*) FROM previstos), 1)                      AS precisao_pct,
    -- linha de base: e se ligássemos para todo mundo, sem régua nenhuma?
    ROUND(100.0 * (SELECT COUNT(*) FROM compraram c JOIN universo u USING (cliente_id))
                / (SELECT COUNT(*) FROM universo), 1)                       AS taxa_se_ligasse_pra_todos;
