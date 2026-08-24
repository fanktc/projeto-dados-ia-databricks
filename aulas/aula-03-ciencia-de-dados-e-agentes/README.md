# 🤖 Dia 3: Ciência de dados e agentes | Imersão Jornada de Dados

> **Status:** os 6 exemplos estão prontos e **rodados**. O modelo tem AUC 0,858,
> o score está gravado em `gold.score_propensao` e o agente monta o briefing
> do vendedor.

Duas noites construindo dado. Hoje ele vira ação: uma lista de clientes que o
vendedor abre de manhã e sabe para quem ligar.

> **Promessa da noite:** o dado vira decisão.
> **Pergunta da noite:** *"Quem eu procuro amanhã, e por quê?"*
> **Depende de:** a `gold.fato_vendas` da [aula-02](../aula-02-engenharia-de-dados).

---

## 🎯 As três perguntas da diretoria

| # | Arquivo | Pergunta |
|---|---|---|
| 01 | `exemplo-01-quem-vai-comprar-sem-modelo.sql` | Quem vai comprar? |
| 02 | `exemplo-02-quem-esta-sumindo-sem-modelo.sql` | Quem está sumindo? |
| 03 | `exemplo-03-quanto-vamos-vender-sem-modelo.sql` | Quanto vamos vender? |

```bash
python3 scripts/run_sql.py aulas/aula-03-ciencia-de-dados-e-agentes/exemplo-01-quem-vai-comprar-sem-modelo.sql
```

---

## 🧠 Por que começar sem modelo

Cada cliente tem um ritmo de compra. Última compra **+** ritmo **=** data
provável da próxima. Isso é uma linha de raciocínio, não um algoritmo — e já
responde as três perguntas.

Não é preguiça, é **linha de base**. Um modelo só justifica a complexidade que
custa se bater a régua simples. Sem essa medida, ninguém sabe se o modelo
ajudou ou se só ficou bonito no slide.

### O que a régua simples já entrega

| Pergunta | Resposta | Como sabemos que presta |
|---|---|---|
| Quem vai comprar? | 896 clientes na janela de 30 dias, **R$ 3.515.297** esperados | Testada contra agosto: acerta **72,7%**, contra 42,3% de ligar para todos |
| Quem está sumindo? | 69 recuperáveis, **R$ 648.694** por trimestre em risco | O corte fixo de 90 dias acusaria 401 — e **231 estão só no ritmo deles** |
| Quanto vamos vender? | out/2026 em **R$ 7,4 mi** (índice sazonal 1,68) | Prevendo agosto sem olhar para ele, errou **1,2%** |

**Cada arquivo termina com o próprio teste.** Uma lista de clientes sem taxa de
acerto medida é palpite com cara de relatório.

---

## 🔬 Roteiro da noite

```
  Já pronto                   Ao vivo
  (01 → 02 → 03)              (04 → 05 → 06)

  as 3 respostas              features, modelo
  em SQL puro                 e o agente que age
```

| # | Arquivo | O que faz |
|---|---|---|
| 04 | `exemplo-04-features-cliente.sql` | 19 features: RFM, ritmo, CRM e mix — 2.590 clientes, alvo em 41,1% |
| 05 | `exemplo-05-modelo-propensao.py` | Treina, compara com a régua, grava `gold.score_propensao` |
| 06 | `exemplo-06-agente-comercial.py` | Monta o briefing do vendedor a partir de 3 ferramentas |

Os exemplos 05 e 06 são Python e usam Databricks Connect:

```bash
cd aulas/aula-04-deploy/perfumesarabe
export DATABRICKS_CONFIG_PROFILE=SEU-PERFIL DATABRICKS_SERVERLESS_COMPUTE_ID=auto
.venv/bin/python ../../aula-03-ciencia-de-dados-e-agentes/exemplo-05-modelo-propensao.py
```

### 📈 O modelo bateu a régua?

Bateu — mas não pelo que a maioria espera:

| | precisão | recall | AUC |
|---|---|---|---|
| Chutar "sim" para todos | 0,411 | 1,000 | — |
| **Régua do exemplo 01** (ritmo de compra) | 0,604 | 0,803 | — |
| **Modelo** (gradient boosting) | **0,709** | 0,740 | 0,858 |

O modelo ganha **10,5 pontos de precisão** e perde 6 de recall. Numa lista de
20 ligações por dia, precisão é o que importa: ele evita ~2 ligações perdidas
a cada 20. É ganho real, e é menor do que o AUC de 0,858 faz parecer.

### 🔍 O que o modelo aprendeu

As variáveis mais importantes, por permutação:

```
  atraso_relativo          0.1001   ← recência dividida pelo ritmo
  recencia_dias            0.0456
  ritmo_dias               0.0260
  valor_total              0.0147
```

**O modelo redescobriu a régua.** `atraso_relativo` é exatamente o que o
exemplo 01 calcula à mão, e sozinho pesa o dobro de todo o resto somado. O
ganho vem do ajuste fino, não de uma ideia nova.

Isso é ótima notícia para a defesa interna: o modelo é explicável, e você
consegue dizer em uma frase por que ele escolheu aquele cliente.

### ⚠️ A regra que não pode ser quebrada

Toda feature usa **só dado anterior** à data de referência (2026-07-31); o
alvo olha os 30 dias seguintes. Se uma feature enxergar o futuro — "total de
pedidos" contando o mês do alvo — o modelo acerta 99% no treino e erra tudo
em produção. Chama-se vazamento, e é o erro mais caro da área.

### 🤖 O agente

Três ferramentas, cada uma uma query:

| Ferramenta | Responde |
|---|---|
| `priorizar_carteira` | quem esse vendedor procura hoje, e por quê |
| `sugerir_produtos` | o que ele comprava e parou |
| `checar_disponibilidade` | tem em estoque? |

A diferença entre agente e chatbot não é o modelo de linguagem: é **de onde
vem o número**. Este agente não sabe nada sobre a Rota do Perfume — só sabe
chamar ferramentas que leem as tabelas das noites 1 e 2.

E quando o dado falta, ele diz que falta. Na execução real ele recusou um
produto: `SKU00008 Dahab · EM RUPTURA — não ofereça`.

---

## ⚠️ O que o dado sustenta, e o que não

Medido antes de treinar qualquer coisa:

**Propensão — use janela de 30 dias.**

| Janela | Compram | Serve? |
|---|---|---|
| 30 dias | 40,7% | sim, equilibrado |
| 60 dias | 68,9% | já desbalanceia |
| 90 dias | 81,4% | não: o modelo aprende a chutar "sim" e acerta 81% |

**Churn — trate como regra, não como modelo.** Só 6,5% dos clientes estão
atrasados frente ao próprio ritmo. É pouco para treinar classificador com
folga, e a régua já resolve.

**Previsão — sazonal, horizonte curto.** São 24 meses = 2 ciclos anuais, o
mínimo absoluto. O mês do ano explica **87%** da variação, mas não há tendência
de crescimento para extrapolar: projetar alta erra para cima.

---

## 🔢 Números-âncora da noite

| Métrica | Valor |
|---|---|
| Clientes com histórico usável (3+ pedidos) | 2.623 de 2.816 |
| Intervalo mediano entre compras | 76 dias |
| Precisão da régua de propensão | 72,7% (linha de base: 42,3%) |
| Receita em risco por trimestre | R$ 648.694 |
| Erro da previsão em agosto/2026 | 1,2% |

---

## ➡️ Amanhã

O score existe, mas roda quando alguém lembra. Amanhã ele vira job agendado,
monitorado e defensável: [aula-04](../aula-04-deploy).
