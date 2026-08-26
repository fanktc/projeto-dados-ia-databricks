-- ML · o modelo vira decisão
--
-- Um score numa tabela não muda nada. `0,8412` não é uma ação — é um número
-- esperando que alguém saiba o que fazer com ele.
--
-- Estas três views existem para transformar o score em três coisas que uma
-- pessoa consegue usar sem saber o que é AUC:
--
--   carteira_do_dia        o vendedor: com quem eu falo amanhã, e por quê
--   receita_em_risco       o diretor: quanto dinheiro está parado, e onde
--   oportunidade_por_faixa a conferência: o score realmente separa?
--
-- Repare no padrão do prompt 6 de ontem: nome de negócio, `COMMENT` dizendo
-- QUAL PERGUNTA a view responde, e toda coluna comentada. É o que faz o Genie
-- responder sobre o modelo sem que ninguém escreva SQL.

-- ── 1 · A carteira do dia ─────────────────────────────────────────────
-- A entrega da noite. Uma linha por cliente prioritário, com o vendedor
-- responsável e o motivo escrito na língua de quem vai ligar.
--
-- O MOTIVO É A PARTE QUE IMPORTA. Um vendedor não age sobre "score 0,84" —
-- ele age sobre "atrasado para o padrão dele". Modelo que não explica não é
-- usado: fica um mês na tela e some. E, quando o modelo erra, o motivo é o que
-- permite alguém dizer POR QUE errou em vez de simplesmente perder a confiança.
CREATE OR REPLACE VIEW lakehouse_rotaperfume.gold.carteira_do_dia (
  vendedor_id      COMMENT 'Vendedor responsável pelo cliente na carteira vigente.',
  vendedor         COMMENT 'Nome do vendedor que deve fazer o contato.',
  regiao           COMMENT 'Região do vendedor.',
  cliente_id       COMMENT 'Identificador do cliente.',
  razao_social     COMMENT 'Nome do cliente a contatar.',
  segmento         COMMENT 'Tipo de varejo do cliente.',
  cidade           COMMENT 'Cidade do cliente.',
  score_propensao  COMMENT 'Probabilidade de 0 a 1 de o cliente comprar nos próximos 30 dias.',
  faixa            COMMENT 'Leitura do score em palavra: Fria, Morna, Quente ou Muito quente.',
  motivo           COMMENT 'Por que este cliente está na lista, escrito para o vendedor ler. É o que faz a lista ser usada em vez de ignorada.',
  dias_sem_comprar COMMENT 'Dias desde o último pedido do cliente.',
  atraso_relativo  COMMENT 'Recência dividida pelo intervalo médio do próprio cliente. Acima de 1 ele está atrasado para o padrão dele.',
  ticket_medio     COMMENT 'Quanto o cliente costuma gastar por pedido. Dá a ordem de grandeza da conversa.',
  receita_mensal_media COMMENT 'Quanto o cliente comprava por mês, em média. É a receita em jogo neste contato.',
  prioridade       COMMENT 'Posição do cliente na fila daquele vendedor: 1 é o primeiro a ligar.'
)
COMMENT 'Responde: com quem cada vendedor deve falar amanhã, em que ordem e por quê? Uma linha por cliente prioritário da carteira vigente.'
AS
WITH base AS (
  SELECT
      ca.vendedor_id, v.nome AS vendedor, v.regiao,
      c.cliente_id, c.razao_social, c.segmento, c.cidade,
      s.score_propensao, s.faixa,
      c.dias_sem_comprar,
      f.atraso_relativo, f.ticket_medio,
      ROUND(c.receita_acumulada
            / NULLIF(months_between(c.ultimo_pedido, c.primeiro_pedido), 0), 2) AS receita_mensal_media,
      -- A ordem dos CASE é a ordem da conversa. O primeiro que casar vence, e
      -- por isso o mais urgente vem primeiro: cliente grande sumindo é o que
      -- não pode esperar a próxima rodada.
      --
      -- Os limiares NÃO foram chutados: saem da distribuição real da carteira.
      -- `atraso_relativo` tem mediana 0,67 aqui, então "> 1" já é o décimo
      -- superior — quem passa disso está mesmo fora do ritmo dele. Um limiar
      -- de 2, que parece redondo e razoável, pegaria UM cliente na base
      -- inteira e o motivo mais útil nunca apareceria na tela.
      CASE
        WHEN f.atraso_relativo > 1 AND c.receita_acumulada > 50000
          THEN 'Cliente grande e atrasado para o padrão dele — ligar hoje'
        WHEN f.atraso_relativo > 1
          THEN concat('Costuma comprar a cada ', CAST(round(f.intervalo_medio_dias) AS INT),
                      ' dias e está há ', c.dias_sem_comprar, ' sem pedido')
        WHEN s.faixa = 'Muito quente' AND c.receita_acumulada > 50000
          THEN 'Alta chance de comprar, e é um dos maiores da carteira'
        WHEN s.faixa = 'Muito quente'
          THEN 'Alta chance de fechar agora — momento certo de oferecer'
        WHEN f.peso_90d < 0.05 AND f.frequencia_pedidos > 5
          THEN 'Cliente antigo esfriando: quase nada da receita dele é recente'
        WHEN f.visitas > 2 AND f.taxa_conversao_visita = 0
          THEN concat(f.visitas, ' visitas e nenhum pedido — rever a abordagem')
        WHEN f.oportunidades > f.oportunidades_ganhas
          THEN 'Tem oportunidade aberta no CRM sem fechamento'
        ELSE 'Rotina de carteira'
      END AS motivo
  FROM lakehouse_rotaperfume.gold.score_propensao s
  JOIN lakehouse_rotaperfume.gold.features_cliente f ON f.cliente_id = s.cliente_id
  JOIN lakehouse_rotaperfume.gold.dim_cliente      c ON c.cliente_id = s.cliente_id
  -- Carteira VIGENTE: o vínculo não terminou e o vendedor não foi desligado.
  -- Sem esta condição, 441 clientes entrariam na lista de gente que não
  -- trabalha mais aqui — a sujeira que a noite 2 expôs em vez de esconder.
  JOIN lakehouse_rotaperfume.silver.carteira ca
       ON ca.cliente_id = s.cliente_id AND ca.vigente
  JOIN lakehouse_rotaperfume.gold.dim_vendedor v ON v.vendedor_id = ca.vendedor_id
)
SELECT vendedor_id, vendedor, regiao, cliente_id, razao_social, segmento, cidade,
       score_propensao, faixa, motivo, dias_sem_comprar, atraso_relativo,
       ticket_medio, receita_mensal_media,
       row_number() OVER (PARTITION BY vendedor_id ORDER BY score_propensao DESC) AS prioridade
FROM base
WHERE score_propensao >= 0.30;   -- abaixo disso o contato não se paga

-- ── 2 · A receita em risco, endereçável ───────────────────────────────
-- A view do prompt 6 de ontem (`clientes_em_risco`) responde QUANTO está
-- parado. Esta responde algo diferente e mais acionável: **quanto dá para
-- tentar recuperar**, separando quem ainda tem chance de quem já foi.
--
-- É a diferença entre um número para o slide e um número para a decisão.
CREATE OR REPLACE VIEW lakehouse_rotaperfume.gold.receita_em_risco (
  faixa               COMMENT 'Faixa de propensão do cliente.',
  clientes            COMMENT 'Quantos clientes em risco (mais de 90 dias sem comprar) estão nesta faixa.',
  receita_mensal_parada COMMENT 'Soma do que esses clientes compravam por mês antes de parar.',
  ticket_medio_faixa  COMMENT 'Ticket médio dos clientes desta faixa.',
  recuperavel         COMMENT 'TRUE nas faixas Quente e Muito quente: o modelo ainda vê chance de compra. É onde o esforço comercial se paga.'
)
COMMENT 'Responde: da receita parada em clientes que sumiram, quanto ainda dá para recuperar e com quem devemos gastar o esforço?'
AS
SELECT
    s.faixa,
    COUNT(*) AS clientes,
    ROUND(SUM(c.receita_acumulada
              / NULLIF(months_between(c.ultimo_pedido, c.primeiro_pedido), 0)), 2) AS receita_mensal_parada,
    ROUND(AVG(f.ticket_medio), 2) AS ticket_medio_faixa,
    (s.faixa IN ('Quente', 'Muito quente')) AS recuperavel
FROM lakehouse_rotaperfume.gold.score_propensao s
JOIN lakehouse_rotaperfume.gold.dim_cliente      c ON c.cliente_id = s.cliente_id
JOIN lakehouse_rotaperfume.gold.features_cliente f ON f.cliente_id = s.cliente_id
WHERE c.dias_sem_comprar > 90
GROUP BY s.faixa;

-- ── 3 · O score separa mesmo? ─────────────────────────────────────────
-- A view mais importante para a CONFIANÇA no modelo, e a que se deveria
-- mostrar primeiro para quem vai usar a lista.
--
-- Ela não fala de AUC: mostra que, na faixa "Muito quente", uma proporção bem
-- maior de gente comprou de fato. Ninguém do comercial precisa entender curva
-- ROC — precisa ver que a ordem funciona, e conferir sozinho.
--
-- ── A ARMADILHA QUE ESTA VIEW QUASE CAIU ──────────────────────────────
--
-- A fonte é `gold.modelo_validacao` (o holdout do treino), e NÃO
-- `gold.score_propensao`. Parece detalhe e não é:
--
--   score_propensao   features de 2026-08-31 → prevê SETEMBRO
--   o rótulo que temos → o que aconteceu em AGOSTO
--
-- Cruzar os dois compara uma previsão de setembro com um resultado de agosto.
-- Em distribuição isso não dá só um número ruim, dá um número INVERTIDO: quem
-- comprou em agosto está com recência baixa em 31/08, o modelo aprendeu que
-- recência baixa significa menos chance no ciclo de reposição, e a faixa
-- "Fria" aparece com a MAIOR taxa de compra.
--
-- O gráfico fica bonito, a conclusão fica ao contrário, e nenhum teste pega —
-- porque tecnicamente as duas tabelas casam pelo `cliente_id`.
CREATE OR REPLACE VIEW lakehouse_rotaperfume.gold.oportunidade_por_faixa (
  faixa            COMMENT 'Faixa de propensão atribuída pelo modelo aos clientes do conjunto de teste.',
  clientes         COMMENT 'Clientes do conjunto de teste naquela faixa.',
  compraram        COMMENT 'Quantos deles realmente fizeram pedido nos 30 dias seguintes ao corte de treino.',
  taxa_de_compra   COMMENT 'Proporção que comprou, de 0 a 1. Tem que crescer de Fria para Muito quente — é a prova visual de que o score ordena.',
  score_medio      COMMENT 'Score médio da faixa.'
)
COMMENT 'Responde: o score realmente separa quem compra de quem não compra? Compara a faixa prevista com o que aconteceu de verdade, usando só clientes que o modelo não viu no treino.'
AS
SELECT
    CASE WHEN score <= 0.30 THEN 'Fria'
         WHEN score <= 0.60 THEN 'Morna'
         WHEN score <= 0.80 THEN 'Quente'
         ELSE 'Muito quente' END      AS faixa,
    COUNT(*)                          AS clientes,
    SUM(comprou_30d)                  AS compraram,
    ROUND(AVG(comprou_30d), 4)        AS taxa_de_compra,
    ROUND(AVG(score), 4)              AS score_medio
FROM lakehouse_rotaperfume.gold.modelo_validacao
GROUP BY 1;
