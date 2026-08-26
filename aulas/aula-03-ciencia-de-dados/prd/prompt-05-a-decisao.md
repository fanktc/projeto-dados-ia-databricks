# Prompt 5 · A decisão — o score vira a lista de amanhã

**Entrega:** três views de negócio — `carteira_do_dia`, `receita_em_risco` e
`oportunidade_por_faixa`. **Deploy nº 5 da noite.**

> **A entrega da noite.** Até agora o modelo é um número numa tabela. `0,8412`
> não é uma ação — é um número esperando que alguém saiba o que fazer com ele.
> Este prompt transforma o score em três coisas que uma pessoa usa sem saber o
> que é AUC.

---

## O que mostrar antes

**1 · O score, do jeito que ele está hoje**

```sql
SELECT * FROM lakehouse_rotaperfume.gold.score_propensao LIMIT 10;
```

> *"Coloquem isso na frente de um vendedor. `cliente_id 1847, score 0,8412`.
> Ele vai perguntar duas coisas: quem é esse cliente, e por que eu deveria
> ligar. E a tabela não responde nenhuma das duas."*

**2 · A pergunta que a noite prometeu responder**

Volte para a promessa da abertura e leia de novo:

> **"Com quem meu vendedor fala amanhã de manhã?"**

> *"A gente tem um modelo com AUC de 0,87 e ainda não respondeu isso. Falta a
> parte que não é ciência de dados: traduzir."*

**3 · O que a noite 2 já ensinou sobre nomes**

```sql
SHOW VIEWS IN lakehouse_rotaperfume.gold;
-- receita_mensal, ranking_marcas, clientes_em_risco, margem_por_categoria…
```

> *"Ontem a gente aprendeu que a view existe para o nome da pergunta e o nome
> da tabela serem a mesma palavra. Hoje é a mesma regra, aplicada ao modelo."*

---

**Enquanto ele trabalha, você explica:**

- **O motivo é a parte que importa, não o score.** Um vendedor não age sobre
  "0,84" — age sobre "atrasado para o padrão dele". Modelo que não explica não
  é usado: fica um mês na tela e some. E quando erra, o motivo é o que permite
  alguém dizer *por que* errou, em vez de simplesmente perder a confiança.
- **A carteira vigente já vem resolvida da noite 2.** A view junta com
  `silver.carteira` onde `vigente` — a coluna que respeita o desligamento do
  vendedor. Sem ela, 441 clientes entrariam na lista de gente que não trabalha
  mais aqui. *A sujeira que a gente expôs ontem em vez de esconder está
  pagando dividendo hoje.*
- **Os limiares saem da distribuição, não de números redondos.**
  `atraso_relativo > 2` parece razoável e pegaria **um** cliente na base
  inteira — porque a mediana da carteira é 0,67. O limiar certo é 1, e isso só
  se descobre olhando o dado.
- **A view de calibragem é a que constrói confiança.** Ela não fala de AUC:
  mostra que na faixa "Muito quente" oito em cada dez compraram, e na "Fria",
  um em cada dez. Qualquer pessoa confere isso sozinha — e é isso que faz ela
  passar a usar a lista.

---

## O prompt

```
Continue o bundle em aulas/aula-02-engenharia-de-dados/rotaperfume/.
gold.score_propensao está pronta e os 8 testes de modelo passam.

src/ml/15-carteira-do-dia.sql — três views, no padrão do prompt 6 de ontem:
nome de negócio, COMMENT dizendo QUAL PERGUNTA a view responde, e COMMENT em
cada coluna.

1. gold.carteira_do_dia
   Uma linha por cliente prioritário, com o vendedor responsável.
   Junte score_propensao + features_cliente + dim_cliente + dim_vendedor e
   silver.carteira COM A CONDIÇÃO vigente — senão entram 441 clientes de
   vendedor desligado.
   Filtre score >= 0.30 e numere com row_number() por vendedor: a coluna
   prioridade diz quem é o primeiro a ligar.

   A COLUNA MOTIVO É A ENTREGA. Um CASE que escreve, na língua do vendedor,
   por que aquele cliente está na lista. Ordene do mais urgente para o mais
   genérico:
     - atraso_relativo > 1 e receita acumulada > 50 mil → cliente grande e
       atrasado, ligar hoje
     - atraso_relativo > 1 → "costuma comprar a cada N dias e está há M sem
       pedido" (monte a frase com os números reais do cliente)
     - Muito quente e cliente grande → alta chance, e é um dos maiores
     - Muito quente → alta chance de fechar agora
     - peso_90d < 0.05 com mais de 5 pedidos → cliente antigo esfriando
     - mais de 2 visitas e nenhuma converteu → rever a abordagem
     - oportunidade aberta no CRM sem fechamento
     - senão: rotina de carteira

   IMPORTANTE sobre os limiares: use 1 e não 2 em atraso_relativo. A mediana
   da carteira é 0,67 — um limiar de 2 pegaria UM cliente na base inteira e o
   motivo mais útil nunca apareceria.

2. gold.receita_em_risco
   Por faixa, entre os clientes com mais de 90 dias sem comprar: quantos são,
   quanto compravam por mês e uma coluna booleana recuperavel (TRUE nas faixas
   Quente e Muito quente). A view clientes_em_risco de ontem responde QUANTO
   está parado; esta responde quanto vale tentar recuperar.

3. gold.oportunidade_por_faixa
   Faixa → clientes, quantos compraram de fato, taxa e score médio.

   LEIA DE gold.modelo_validacao (o holdout do treino), NUNCA de
   score_propensao. Motivo: score_propensao usa features de 2026-08-31 e prevê
   setembro, enquanto o rótulo que temos é de agosto. Cruzar os dois compara
   uma previsão de setembro com um resultado de agosto — e em distribuição
   isso não dá só um número ruim, dá um número INVERTIDO, com a faixa "Fria"
   aparecendo com a maior taxa de compra.

4. Acrescente a tarefa ml_carteira_do_dia ao pipeline, depois de ml_testes.

5. Rode validate, deploy e run com --profile projeto-dados-ia.
```

---

## Como verificar a feature

**1 · A prova de que o score separa — mostre esta primeiro**

```sql
SELECT faixa, clientes, compraram,
       ROUND(100 * taxa_de_compra, 1) AS pct_que_comprou
FROM lakehouse_rotaperfume.gold.oportunidade_por_faixa
ORDER BY score_medio;
```

| Faixa | Clientes | Compraram | % |
|---|---|---|---|
| Fria | 324 | 38 | **11,7%** |
| Morna | 122 | 53 | 43,4% |
| Quente | 83 | 48 | 57,8% |
| Muito quente | 175 | 142 | **81,1%** |

> *"Não é AUC, não é curva ROC, não é nada que precise de explicação. Na faixa
> que o modelo chamou de muito quente, **oito em cada dez compraram**. Na que
> ele chamou de fria, **um em cada dez**. Sete vezes mais.*
>
> *E esses 704 clientes o modelo nunca viu no treino. É o teste honesto."*

**2 · A carteira de um vendedor — a tela que fecha a noite**

```sql
SELECT prioridade, razao_social, cidade, faixa,
       ROUND(score_propensao, 3) AS score, motivo
FROM lakehouse_rotaperfume.gold.carteira_do_dia
WHERE vendedor_id = 1
ORDER BY prioridade LIMIT 10;
```

Troque o `vendedor_id` e mostre outra carteira: **a lista muda inteira.**

> *"Isso é o que o vendedor abre às 8h da manhã. Não é um dashboard com a
> receita do trimestre — é o nome de quem ligar, na ordem, com a frase que
> explica por quê."*

**3 · A distribuição dos motivos — o modelo falando português**

```sql
SELECT motivo, COUNT(*) AS clientes
FROM lakehouse_rotaperfume.gold.carteira_do_dia
GROUP BY motivo ORDER BY clientes DESC LIMIT 8;
```

| Clientes | Motivo |
|---|---|
| 388 | Tem oportunidade aberta no CRM sem fechamento |
| 252 | Alta chance de fechar agora — momento certo de oferecer |
| 211 | Alta chance de comprar, e é um dos maiores da carteira |
| 129 | Rotina de carteira |
| 83 | Cliente antigo esfriando: quase nada da receita dele é recente |
| **35** | **Cliente grande e atrasado para o padrão dele — ligar hoje** |

> *"Olhem os 35 da última linha. Essa é a lista que o diretor comercial quer
> ver na segunda de manhã — clientes grandes saindo do ritmo, enquanto ainda dá
> tempo. Ela não existia há uma hora."*

E as frases personalizadas, que são a melhor demonstração:

```sql
SELECT razao_social, motivo
FROM lakehouse_rotaperfume.gold.carteira_do_dia
WHERE motivo LIKE 'Costuma comprar%'
ORDER BY score_propensao DESC LIMIT 5;
-- "Costuma comprar a cada 89 dias e está há 92 sem pedido"
```

**4 · Quanto dinheiro isso endereça**

```sql
SELECT faixa, clientes, ROUND(receita_mensal_parada, 2) AS parada, recuperavel
FROM lakehouse_rotaperfume.gold.receita_em_risco
ORDER BY parada DESC;
```

| Faixa | Clientes | Receita mensal parada | Recuperável |
|---|---|---|---|
| Fria | 316 | R$ 684.050,65 | não |
| Muito quente | 61 | R$ 42.560,73 | **sim** |
| Quente | 51 | R$ 34.123,59 | **sim** |
| Morna | 31 | R$ 27.931,85 | não |

```sql
SELECT SUM(clientes) AS clientes, ROUND(SUM(receita_mensal_parada), 2) AS receita
FROM lakehouse_rotaperfume.gold.receita_em_risco WHERE recuperavel;
-- 112 clientes · R$ 76.684,32 por mês
```

> *"Aqui está a parte honesta, e é a que mais vale dizer em voz alta: de
> R$ 788 mil por mês parados em clientes que sumiram, o modelo diz que
> **R$ 76 mil valem o esforço agora** — 112 clientes.*
>
> *Um modelo mal calibrado diria 'ataque os 459'. Este diz onde a ligação tem
> chance de virar pedido. Focar em 112 nomes é uma resposta muito mais útil do
> que uma lista de 459 que ninguém vai conseguir percorrer."*

**5 · O Genie responde sobre o modelo, sem ninguém escrever SQL**

O Genie space da noite 2 já lê a gold. Pergunte:

> *"Quais clientes o vendedor 1 deve procurar primeiro?"*
>
> *"Quanta receita a gente consegue recuperar de clientes que pararam de
> comprar?"*

> *"Repare no que aconteceu: eu não configurei nada no Genie hoje. As views
> novas têm nome de negócio e `COMMENT` dizendo qual pergunta respondem — e é
> só isso que ele precisa. O trabalho de metadado de ontem está pagando de
> novo."*

---

## Se der errado ao vivo

| Sintoma | Causa | Correção em um prompt |
|---|---|---|
| A faixa "Fria" tem a maior taxa de compra | `oportunidade_por_faixa` está lendo `score_propensao` | Tem que ler `modelo_validacao`: são pontos diferentes no tempo |
| Quase todo mundo cai em "Rotina de carteira" | Os limiares do `CASE` estão altos demais | Olhe a distribuição real antes de escolher: a mediana de `atraso_relativo` é 0,67 |
| A carteira tem cliente de vendedor desligado | Faltou `AND ca.vigente` no join | É a coluna que a noite 2 criou exatamente para isso |
| Um cliente aparece para dois vendedores | Carteira com dois vínculos vigentes | Investigue: é sujeira de origem, e a view está certa em mostrar |
| O Genie não acha as views novas | Elas não estão nos `data_sources` do space | Acrescente ao `comercial.geniespace.json` e faça deploy |

**Tempo medido:** ~20 segundos (são três views).

---

## O que fica de pé

| Objeto | O quê |
|---|---|
| `gold.carteira_do_dia` | 1.290 contatos priorizados, 36 vendedores, com motivo em português |
| `gold.receita_em_risco` | R$ 76.684/mês recuperáveis em 112 clientes |
| `gold.oportunidade_por_faixa` | a prova de calibragem: 11,7% → 81,1% |
| Job | `rotaperfume_pipeline` com 17 tarefas |
