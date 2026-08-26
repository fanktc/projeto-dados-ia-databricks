-- ML · os 8 testes do modelo
--
-- Ontem os testes perguntavam se o DADO está certo. Estes perguntam se o
-- MODELO está certo, e a diferença não é pequena:
--
--   Um dado errado quebra. Um modelo ruim FUNCIONA.
--
-- Ele devolve número para todo mundo, na faixa esperada, sem lançar exceção
-- nenhuma. O pipeline fica verde, o dashboard atualiza, e o vendedor liga para
-- a lista errada por seis meses. Nada no sistema reclama — porque, do ponto de
-- vista do software, está tudo funcionando.
--
-- É por isso que teste de modelo precisa ser explícito. E, como os de ontem,
-- estes QUEBRAM o job: melhor o comercial usar a lista da semana passada do
-- que uma lista pior que sorteio.
--
-- Os quatro primeiros são sobre qualidade. Os quatro últimos são sobre
-- entrega — e são os que mais pegam problema na vida real, porque um modelo
-- ótimo que não pontuou metade da base é um modelo inútil.

-- ── 1 · O modelo ganha do baseline ────────────────────────────────────
-- O TESTE MAIS IMPORTANTE DA TAREFA, e o que quase ninguém escreve.
--
-- Modelo que não ganha da regra de graça é complexidade sem retorno: custa
-- retreino, custa explicação, custa confiança quando erra — e entrega o que
-- um ORDER BY entregaria. A pergunta certa nunca é "o AUC está bom?", é
-- "está melhor do que o que já fazíamos sem ele?".
SELECT '1 · modelo ganha do baseline' AS teste,
       concat(round(auc, 4), ' vs ', round(baseline_auc, 4)) AS calculado,
       'ganho de pelo menos 0,05' AS esperado,
       CASE WHEN ganho_sobre_baseline >= 0.05 THEN 'PASSOU'
            ELSE raise_error(concat('O modelo ganha apenas ', round(ganho_sobre_baseline, 4),
                                    ' do baseline. Ele não se paga: use a regra simples.'))
       END AS resultado
FROM lakehouse_rotaperfume.gold.modelo_metricas
WHERE _treinado_em = (SELECT max(_treinado_em) FROM lakehouse_rotaperfume.gold.modelo_metricas);

-- ── 2 · AUC acima do mínimo aceitável ─────────────────────────────────
-- 0,70 é o piso combinado com o negócio, não uma constante da natureza.
-- O valor certo sai da conversa: quanto custa uma visita perdida?
SELECT '2 · AUC acima do mínimo' AS teste,
       CAST(round(auc, 4) AS STRING) AS calculado, '>= 0,70' AS esperado,
       CASE WHEN auc >= 0.70 THEN 'PASSOU'
            ELSE raise_error(concat('AUC de ', round(auc, 4), ', abaixo do mínimo de 0,70'))
       END AS resultado
FROM lakehouse_rotaperfume.gold.modelo_metricas
WHERE _treinado_em = (SELECT max(_treinado_em) FROM lakehouse_rotaperfume.gold.modelo_metricas);

-- ── 3 · Bom demais para ser verdade ───────────────────────────────────
-- O teste que salva a carreira de quem está começando.
--
-- AUC de 0,99 em previsão de comportamento humano não é talento: é uma coluna
-- que enxergou o futuro. Alguém calculou a feature DEPOIS do rótulo, e o
-- modelo está "prevendo" o que já aconteceu. Em produção ele desaba — e aí
-- ninguém entende por quê, porque na validação estava lindo.
--
-- Quebrar o job quando o resultado é bom demais parece contraintuitivo. É
-- exatamente por isso que funciona.
SELECT '3 · AUC não é bom demais' AS teste,
       CAST(round(auc, 4) AS STRING) AS calculado, '< 0,99' AS esperado,
       CASE WHEN auc < 0.99 THEN 'PASSOU'
            ELSE raise_error(concat('AUC de ', round(auc, 4),
                                    '. Bom demais: procure vazamento de dado nas features.'))
       END AS resultado
FROM lakehouse_rotaperfume.gold.modelo_metricas
WHERE _treinado_em = (SELECT max(_treinado_em) FROM lakehouse_rotaperfume.gold.modelo_metricas);

-- ── 4 · O rótulo não desequilibrou ────────────────────────────────────
-- Se a janela do rótulo mudar de tamanho sem ninguém perceber, a taxa de
-- positivos desanda e o AUC deixa de significar o que significava.
SELECT '4 · rótulo equilibrado' AS teste,
       CAST(round(taxa_positiva, 4) AS STRING) AS calculado, 'entre 0,15 e 0,85' AS esperado,
       CASE WHEN taxa_positiva BETWEEN 0.15 AND 0.85 THEN 'PASSOU'
            ELSE raise_error(concat('Taxa de positivos em ', round(taxa_positiva, 4),
                                    '. A janela do rótulo mudou de comportamento.'))
       END AS resultado
FROM lakehouse_rotaperfume.gold.modelo_metricas
WHERE _treinado_em = (SELECT max(_treinado_em) FROM lakehouse_rotaperfume.gold.modelo_metricas);

-- ── 5 · Todo cliente ativo tem score ──────────────────────────────────
-- O modo silencioso de falhar: um join perdeu 300 clientes e o vendedor
-- simplesmente nunca mais vê aqueles nomes na lista. Não falta erro na tela,
-- falta gente.
SELECT '5 · cobertura do score' AS teste,
       concat(pontuados, ' de ', com_historico) AS calculado, 'todos' AS esperado,
       CASE WHEN pontuados = com_historico THEN 'PASSOU'
            ELSE raise_error(concat(com_historico - pontuados,
                                    ' clientes com histórico ficaram sem score'))
       END AS resultado
FROM (SELECT (SELECT count(*) FROM lakehouse_rotaperfume.gold.score_propensao)  AS pontuados,
             (SELECT count(*) FROM lakehouse_rotaperfume.gold.features_cliente) AS com_historico);

-- ── 6 · O score é uma probabilidade ───────────────────────────────────
-- Pega o erro de usar `predict()` no lugar de `predict_proba()`: em vez de
-- probabilidade vem a classe, e a coluna inteira vira zero e um.
SELECT '6 · score é probabilidade' AS teste,
       concat('min ', round(minimo, 4), ' · max ', round(maximo, 4),
              ' · valores distintos ', distintos) AS calculado,
       'entre 0 e 1, contínuo' AS esperado,
       CASE WHEN minimo >= 0 AND maximo <= 1 AND distintos > 50 THEN 'PASSOU'
            ELSE raise_error(concat('Score fora de faixa ou com apenas ', distintos,
                                    ' valores distintos — predict() no lugar de predict_proba()?'))
       END AS resultado
FROM (SELECT min(score_propensao) AS minimo, max(score_propensao) AS maximo,
             count(DISTINCT score_propensao) AS distintos
      FROM lakehouse_rotaperfume.gold.score_propensao);

-- ── 7 · A distribuição não degenerou ──────────────────────────────────
-- Um modelo que joga 95% da base numa faixa só não prioriza nada: ele
-- devolveu a lista inteira com outro nome. É um jeito de falhar que o AUC
-- às vezes não pega.
SELECT '7 · distribuição do score' AS teste,
       concat('maior faixa com ', round(100.0 * maior / total, 1), '%') AS calculado,
       'nenhuma faixa acima de 90%' AS esperado,
       CASE WHEN maior < 0.90 * total THEN 'PASSOU'
            ELSE raise_error(concat('Uma única faixa concentra ', round(100.0 * maior / total, 1),
                                    '% dos clientes: o score não está separando ninguém'))
       END AS resultado
FROM (SELECT max(n) AS maior, sum(n) AS total
      FROM (SELECT faixa, count(*) AS n
            FROM lakehouse_rotaperfume.gold.score_propensao GROUP BY faixa));

-- ── 8 · O score é do modelo que está em produção ──────────────────────
-- Cenário real: alguém promove uma versão nova e a tarefa de score falha
-- naquela noite. No dia seguinte o dashboard mostra número do modelo antigo
-- com a versão nova no rótulo, e a discussão sobre "por que mudou" começa
-- errada. Esta linha impede isso.
SELECT '8 · score veio do modelo @prod' AS teste,
       concat(count(DISTINCT versao_modelo), ' versão(ões) na tabela') AS calculado,
       'exatamente 1' AS esperado,
       CASE WHEN count(DISTINCT versao_modelo) = 1 THEN 'PASSOU'
            ELSE raise_error('A tabela de score tem linhas de versões diferentes do modelo')
       END AS resultado
FROM lakehouse_rotaperfume.gold.score_propensao;

-- ── Relatório final, que não quebra nada ──────────────────────────────
-- Para a conversa com quem vai usar a lista.
SELECT m.versao AS versao_modelo,
       round(m.auc, 4)                  AS auc,
       round(m.baseline_auc, 4)         AS baseline,
       round(m.ganho_sobre_baseline, 4) AS ganho,
       m.feature_mais_importante,
       (SELECT count(*) FROM lakehouse_rotaperfume.gold.score_propensao) AS clientes_pontuados,
       (SELECT count(*) FROM lakehouse_rotaperfume.gold.score_propensao
         WHERE faixa = 'Muito quente')                                   AS muito_quentes,
       m._treinado_em
FROM lakehouse_rotaperfume.gold.modelo_metricas m
WHERE m._treinado_em = (SELECT max(_treinado_em) FROM lakehouse_rotaperfume.gold.modelo_metricas);
