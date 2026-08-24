# 🎯 Dinâmica do Design Sprint · slides 16 a 25

Cinco dinâmicas em dez slides, mais um de fechamento que liga tudo ao código: **primeiro só a pergunta** (para a turma
responder), **depois a pergunta com as respostas** do nosso caso.

Rode antes de abrir qualquer ferramenta. O objetivo não é chegar na resposta
certa — é a turma perceber que já tinha as perguntas, só não tinha como
responder.

> **Como conduzir:** projete o slide ímpar, dê 2 minutos, colha 3 ou 4
> respostas em voz alta. Só então avance para o slide par. Se você mostrar as
> respostas antes, viram gabarito e ninguém pensa.

---

## 1 · Como poderíamos… (slides 16-17)

**A pergunta:** transformar cada problema numa frase que começa com "como
poderíamos".

**A regra que faz a dinâmica funcionar:** nenhuma frase pode conter a solução.
"Como poderíamos ter um dashboard" está errado — dashboard é resposta. O certo
é "como poderíamos saber quem vai comprar".

Respostas do nosso caso:

- …saber quem vai comprar antes de o vendedor sair para a rua?
- …perceber que um cliente sumiu enquanto ainda dá para trazer de volta?
- …evitar as **4.946 visitas** que encontram o cliente ausente?
- …saber em julho quanto outubro vai vender, para comprar estoque a tempo?
- …descobrir se vender mais está dando lucro, e não só faturamento?

---

## 2 · Nossa meta de 2 anos (slides 18-19)

**A pergunta:** onde queremos estar em agosto de 2028? Escreva **no passado**,
como se já tivesse acontecido — isso força concretude.

- Todo vendedor abre a lista do dia já priorizada, e confia nela
- O churn caiu de **6,5% para 4%** da base com histórico
- A conversão da visita subiu de **46% para 55%**
- Recuperamos os **R$ 648 mil por trimestre** que hoje somem sem ninguém ver
- Ninguém mais pergunta na reunião de onde veio aquele número

**Meta sem número é desejo.** Cada linha tem um valor medido hoje, então daqui
a dois anos dá para dizer se aconteceu.

---

## 3 · O que pode dar errado? (slides 20-21)

**A pergunta:** levantar risco **antes** de construir.

| Risco | Como mitigar |
|---|---|
| Dado sujo derruba a análise | Camada silver e 9 testes que quebram o pipeline |
| Ninguém usa a lista | Começar com 1 vendedor, medir, só então expandir |
| O modelo vira caixa-preta | Régua explicável de 72,7% como piso obrigatório |
| O custo estoura | Serverless, e medir consumo por execução desde o dia 1 |
| Pedem o que o dado não sustenta | Dizer não cedo, e mostrar por quê |

O último é o mais difícil: dizer "com esse dado, não dá" para um diretor. No
nosso caso é o estoque, que cobre só **27,4% das semanas por SKU** — melhor
falar isso na segunda-feira do que no fim do trimestre.

---

## 4 · Quem faz o quê? (slides 22-23)

**A pergunta:** mapear o caminho da pergunta até a ação, e o caminho de volta.

```
   DIRETORIA ──pergunta──→ ANALISTA ──lista──→ VENDEDOR
       ▲                                          │
       │                                       visita
    relatório                                     ▼
       │                                       CLIENTE
       └──────── SISTEMA ◄──── pedido ────────────┘
                (ERP/CRM)
```

- **DIRETORIA** pergunta "quem vai comprar?" e cobra a resposta na segunda
- **ANALISTA** transforma a pergunta em query, e a query em tabela que roda sozinha
- **VENDEDOR** abre a lista, escolhe 20 nomes e sai para a rua
- **CLIENTE** compra — ou não atende, ou pede justo o que está em ruptura
- **SISTEMA** registra tudo, e o pedido de hoje vira o dado de amanhã

**O fluxo é um círculo, não uma linha.** O que o vendedor faz hoje alimenta o
modelo que vai orientá-lo na semana que vem. É por isso que a qualidade do
registro importa: ninguém preenche CRM pensando em treinar modelo, mas é o que
acontece.

---

## 🔗 Da dinâmica para o código (slide 26)

O slide que fecha o bloco. **As cinco linhas são exatamente as cinco perguntas
da dinâmica 1, na mesma ordem** — a turma vê a própria lista voltando, agora
com o caminho de cada uma.

| # | A pergunta que a turma escreveu | A query | Quando |
|---|---|---|---|
| 1 | Quem vai comprar? | Última compra + ritmo do cliente | noite 3 |
| 2 | Quem está sumindo? | Recência comparada ao ritmo dele | noite 3 |
| 3 | Evitar a visita perdida? | É a mesma lista, priorizada | noite 3 |
| 4 | Quanto vamos vender? | Índice sazonal por mês do ano | noite 3 |
| 5 | Vender mais dá lucro? | Margem por categoria | **hoje** |

**O que dizer:**

> Das cinco que vocês perguntaram, hoje eu respondo uma. As outras quatro
> dependem de dado limpo — e é exatamente por isso que existe a noite 2.

Responder só uma de cinco não é fraqueza do roteiro: é o argumento. A turma
acabou de escrever cinco perguntas boas e descobre que quatro delas travam no
mesmo lugar — o dado sujo. A noite 2 deixa de ser "mais um dia de aula" e vira
a resposta a um problema que eles mesmos levantaram.

### Rodando ao vivo a que dá para responder hoje

```bash
python3 scripts/run_sql.py aulas/aula-01-databricks-sql/exemplo-06-margem-marca-e-sazonalidade.sql
```

Se quiser dar o gostinho da noite 3 (roda em 25 segundos):

```bash
python3 scripts/run_sql.py aulas/aula-03-ciencia-de-dados-e-agentes/exemplo-01-quem-vai-comprar-sem-modelo.sql
```

---

## 5 · Qual é a menor coisa que já responde? (slides 24-25)

**A pergunta:** o que é o protótipo? Não o produto final — o suficiente para
saber se a ideia presta.

- O protótipo foi **uma query**: última compra + ritmo de compra do cliente
- Zero modelo, zero dashboard, zero aplicativo — **40 linhas de SQL**
- O teste levou **25 segundos**: 72,7% de acerto contra 42,3% de ligar para todos
- Só então o modelo entrou — e teve de bater esse número para se justificar
- O que **não** fizemos: interface, integração e pipeline antes de saber se funcionava

**Protótipo que leva uma semana não é protótipo.** Se a ideia for ruim, você
quer descobrir hoje, não depois de a equipe já ter construído.

**A deixa para o próximo slide:** *"agora pegue as cinco perguntas da dinâmica
1 — qual delas dá para prototipar hoje, com uma query?"* Deixe a turma tentar
responder antes de avançar.

Para rodar ao vivo (25 segundos):

```bash
python3 scripts/run_sql.py aulas/aula-03-ciencia-de-dados-e-agentes/exemplo-01-quem-vai-comprar-sem-modelo.sql
```
