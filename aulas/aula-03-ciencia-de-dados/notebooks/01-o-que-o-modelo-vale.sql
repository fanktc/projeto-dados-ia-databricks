-- ═══════════════════════════════════════════════════════════════════════
-- Noite 3 · O que o modelo vale
--
-- O notebook para abrir DEPOIS que o pipeline rodou. Seis perguntas, na ordem
-- em que uma pessoa cética faria — começando pela única que importa:
-- de 200 ligações, quantas viram pedido a mais por causa do modelo?
--
-- Rode no SQL Editor ou como notebook SQL. Tudo aqui é leitura.
-- ═══════════════════════════════════════════════════════════════════════


-- ── 1 · O modelo se paga? ─────────────────────────────────────────────
-- A primeira pergunta, e a que quase nunca é feita. AUC sozinho não responde
-- nada: o que interessa é a DISTÂNCIA para a regra que você usaria de graça.
-- lift_top200 = a taxa de compra dos 200 primeiros dividida pela taxa base.
SELECT versao                              AS versao_do_modelo,
       ROUND(100 * taxa_base, 1)           AS pct_se_ligasse_aleatorio,
       acertos_top200                      AS dos_200_quantos_compram,
       ROUND(lift_top200, 2)               AS quantas_vezes_melhor,
       ROUND(auc, 4)                       AS auc_modelo,
       ROUND(baseline_valor_total, 4)      AS auc_ligue_para_os_maiores,
       ROUND(baseline_recencia, 4)         AS auc_ligue_para_quem_sumiu,
       feature_mais_importante,
       _treinado_em
FROM lakehouse_rotaperfume.gold.modelo_metricas
ORDER BY _treinado_em DESC;

-- O que procurar: auc_ligue_para_quem_sumiu ABAIXO de 0,5. Não é erro de
-- conta — é a intuição comercial invertida. Distribuição funciona por ciclo
-- de reposição: quem acabou de receber a mercadoria é quem não compra agora.


-- ── 2 · A prova que o comercial entende ───────────────────────────────
-- Ninguém precisa saber o que é curva ROC para conferir isto: a taxa de
-- compra tem que SUBIR de Fria para Muito quente. Se sobe, o score ordena.
-- Se não sobe, nenhum AUC bonito salva o modelo.
SELECT faixa, clientes, compraram,
       ROUND(100 * taxa_de_compra, 1) AS pct_que_comprou,
       ROUND(score_medio, 4)          AS score_medio
FROM lakehouse_rotaperfume.gold.calibragem_holdout
ORDER BY score_medio;


-- ── 3 · A fila da semana, que é a resposta do diretor ─────────────────
-- Os 200 maiores scores da base inteira, divididos por vendedor. Cada linha
-- tem nome, motivo e o que oferecer. É o que o vendedor abre na segunda.
SELECT vendedor, ordem, razao_social, cidade, uf,
       ROUND(score, 2) AS score, faixa, motivo, sugestao
FROM lakehouse_rotaperfume.gold.fila_semanal
ORDER BY vendedor, ordem
LIMIT 30;   -- os primeiros vendedores da lista


-- ── 4 · A fila é uma fila mesmo? ──────────────────────────────────────
-- Quem recebeu muitas ligações e quem recebeu poucas. A fila é global, então
-- quem aparece no topo não é o melhor vendedor: é o que tem a carteira mais
-- quente. É conversa de negócio, não bug do modelo — e só existe porque
-- agora tem número.
SELECT vendedor,
       COUNT(*)                                              AS ligacoes,
       SUM(CASE WHEN faixa = 'Muito quente' THEN 1 ELSE 0 END) AS muito_quentes,
       ROUND(AVG(score), 3)                                  AS score_medio,
       ROUND(SUM(ticket_medio), 2)                           AS potencial_da_semana
FROM lakehouse_rotaperfume.gold.fila_semanal
GROUP BY vendedor
ORDER BY score_medio DESC;


-- ── 5 · Onde o modelo discorda da intuição ────────────────────────────
-- Os clientes que entraram na fila e NÃO entrariam pela regra do gerente
-- ("ligue para quem sumiu há mais tempo"). É aqui que o modelo ganha o
-- dinheiro dele — e é a lista que convence o cético da sala.
WITH pela_intuicao AS (
  SELECT cliente_id
  FROM lakehouse_rotaperfume.gold.features_cliente
  ORDER BY recencia_dias DESC
  LIMIT 200)
SELECT f.razao_social,
       ROUND(f.score, 2)                AS score,
       c.recencia_dias,
       ROUND(c.intervalo_medio_dias, 0) AS compra_a_cada,
       ROUND(c.atraso_relativo, 1)      AS atraso,
       f.motivo
FROM lakehouse_rotaperfume.gold.fila_semanal f
JOIN lakehouse_rotaperfume.gold.features_cliente c USING (cliente_id)
WHERE f.cliente_id NOT IN (SELECT cliente_id FROM pela_intuicao)
ORDER BY f.score DESC
LIMIT 15;


-- ── 6 · A auditoria: de que corte veio cada número ────────────────────
-- A pergunta que aparece daqui a seis meses. A resposta não pode ser "acho
-- que foi em agosto" — tem que ser uma coluna.
SELECT 'features_treino'  AS tabela, MIN(_referencia) AS corte, COUNT(*) AS linhas
FROM lakehouse_rotaperfume.gold.features_treino
UNION ALL
SELECT 'features_cliente', MIN(_referencia), COUNT(*)
FROM lakehouse_rotaperfume.gold.features_cliente
UNION ALL
SELECT 'score_propensao',  MIN(_referencia), COUNT(*)
FROM lakehouse_rotaperfume.gold.score_propensao;

-- E o modelo, do lado das tabelas, no mesmo catálogo:
SHOW MODELS IN lakehouse_rotaperfume.gold;
