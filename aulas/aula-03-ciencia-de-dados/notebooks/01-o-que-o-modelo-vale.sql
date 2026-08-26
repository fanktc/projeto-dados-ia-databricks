-- ═══════════════════════════════════════════════════════════════════════
-- Noite 3 · O que o modelo vale
--
-- O notebook para abrir DEPOIS que o pipeline rodou. São sete perguntas, na
-- ordem em que uma pessoa cética faria — começando pela única que importa:
-- o modelo é melhor do que não ter modelo nenhum?
--
-- Rode no SQL Editor ou como notebook SQL. Tudo aqui é leitura.
-- ═══════════════════════════════════════════════════════════════════════


-- ── 1 · O modelo se paga? ─────────────────────────────────────────────
-- A primeira pergunta, e a que quase nunca é feita. AUC de 0,5 é jogar moeda;
-- o que interessa não é o AUC do modelo sozinho, é a DISTÂNCIA dele para a
-- regra que você usaria de graça.
SELECT versao                          AS versao_do_modelo,
       ROUND(auc, 4)                   AS auc_modelo,
       ROUND(baseline_auc, 4)          AS auc_da_regra_simples,
       ROUND(ganho_sobre_baseline, 4)  AS ganho,
       feature_mais_importante,
       ROUND(taxa_positiva, 4)         AS taxa_positiva_no_treino,
       linhas_treino, linhas_teste,
       _treinado_em
FROM lakehouse_rotaperfume.gold.modelo_metricas
ORDER BY _treinado_em DESC;


-- ── 2 · A prova que o comercial entende ───────────────────────────────
-- Ninguém precisa saber o que é curva ROC para conferir isto: a taxa de
-- compra tem que SUBIR de Fria para Muito quente. Se subir, o score ordena.
-- Se não subir, o modelo não está separando ninguém — e nenhum AUC bonito
-- salva.
SELECT faixa, clientes, compraram,
       ROUND(100 * taxa_de_compra, 1) AS pct_que_comprou,
       ROUND(score_medio, 4)          AS score_medio
FROM lakehouse_rotaperfume.gold.oportunidade_por_faixa
ORDER BY score_medio;


-- ── 3 · O que o modelo realmente olhou ────────────────────────────────
-- Importância por permutação: quanto o AUC piora ao embaralhar cada coluna.
--
-- O que procurar aqui: se `atraso_relativo` estiver no topo, o argumento da
-- noite se prova sozinho — a coluna que mais pesa não veio de biblioteca
-- nenhuma, veio de saber que "sumiu há 20 dias" significa coisas opostas
-- para quem compra toda semana e para quem compra por trimestre.
SELECT feature,
       ROUND(peso, 5) AS quanto_o_auc_piora_sem_ela,
       versao
FROM lakehouse_rotaperfume.gold.modelo_importancia
ORDER BY peso DESC;


-- ── 4 · A distribuição do score ───────────────────────────────────────
-- Uma faixa que concentra quase todo mundo é um modelo que devolveu a lista
-- inteira com outro nome. O teste 7 do pipeline quebra nesse caso.
SELECT faixa,
       COUNT(*)                                              AS clientes,
       ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1)    AS pct,
       ROUND(MIN(score_propensao), 4)                        AS score_min,
       ROUND(MAX(score_propensao), 4)                        AS score_max
FROM lakehouse_rotaperfume.gold.score_propensao
GROUP BY faixa
ORDER BY score_min;


-- ── 5 · A carteira de um vendedor ─────────────────────────────────────
-- A entrega da noite, do jeito que o vendedor recebe: nome, motivo e ordem.
-- Troque o vendedor_id e mostre outra carteira — a lista muda inteira, e é
-- isso que prova que a priorização é por pessoa, não uma lista geral.
SELECT prioridade, razao_social, cidade, faixa,
       ROUND(score_propensao, 3) AS score,
       motivo,
       dias_sem_comprar,
       ROUND(receita_mensal_media, 2) AS receita_mensal_media
FROM lakehouse_rotaperfume.gold.carteira_do_dia
WHERE vendedor_id = 1
ORDER BY prioridade
LIMIT 15;


-- ── 6 · Quanto dinheiro isso endereça ─────────────────────────────────
-- A tradução do modelo para a língua da diretoria. `recuperavel` separa onde
-- o esforço comercial ainda se paga de onde virou custo afundado.
SELECT faixa, clientes,
       ROUND(receita_mensal_parada, 2) AS receita_mensal_parada,
       ROUND(ticket_medio_faixa, 2)    AS ticket_medio,
       recuperavel
FROM lakehouse_rotaperfume.gold.receita_em_risco
ORDER BY receita_mensal_parada DESC;

-- E o total endereçável, que é o número para o slide:
SELECT ROUND(SUM(receita_mensal_parada), 2) AS receita_mensal_recuperavel,
       SUM(clientes)                        AS clientes_para_atacar
FROM lakehouse_rotaperfume.gold.receita_em_risco
WHERE recuperavel;


-- ── 7 · O modelo é objeto de catálogo ─────────────────────────────────
-- A tabela de score sabe qual versão do modelo a gerou. É o que permite
-- responder "por que este cliente estava na lista em setembro?" seis meses
-- depois — em vez de "não sei, o modelo mudou desde então".
SELECT versao_modelo,
       modelo,
       COUNT(*)          AS clientes_pontuados,
       MAX(_pontuado_em) AS pontuado_em
FROM lakehouse_rotaperfume.gold.score_propensao
GROUP BY versao_modelo, modelo;

-- E o histórico de decisões de promoção — inclusive as recusas:
SELECT versao_challenger, versao_prod_anterior,
       ROUND(auc_challenger, 4)    AS auc_challenger,
       ROUND(auc_prod_anterior, 4) AS auc_anterior,
       promovido, motivo, _decidido_em
FROM lakehouse_rotaperfume.gold.modelo_promocoes
ORDER BY _decidido_em DESC;
