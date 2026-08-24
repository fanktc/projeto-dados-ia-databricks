# 🤖 Dia 3: Ciência de dados e agentes | Imersão Jornada de Dados

> **Status:** os três exemplos em SQL **já estão prontos e testados**. O modelo
> e o agente entram ao vivo na quarta, 26/08.

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
| 04 | `exemplo-04-features-cliente.sql` | RFM + sinais de CRM (visita, funil) sobre a gold |
| 05 | `exemplo-05-modelo-propensao.py` | Treino, AUC medido **contra os 72,7%**, score versionado |
| 06 | `exemplo-06-agente-comercial.py` | Lê score e estoque, decide o que o vendedor faz hoje |

O agente não inventa número: ele só responde através de ferramentas que
consultam as tabelas construídas nas noites anteriores. É isso que separa
agente de chatbot.

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
