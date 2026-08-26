# 🔮 Dia 3: Ciência de dados e agentes de IA | Imersão Jornada de Dados

Ontem o pipeline passou a rodar sozinho. Ele responde muito bem uma pergunta:
**o que aconteceu.** Receita por mês, margem por categoria, quem parou de
comprar.

Hoje ele passa a responder outra — e é a única que o diretor comercial fez:

> **"Tenho 3.000 clientes. O time consegue ligar para 200 por semana.
> Quais 200?"**

> **Promessa da noite:** o dado vira fila de ligação.
> **Formato:** [3 prompts, 3 deploys](prd/3-prompts-noite-3.md). O mesmo bundle
> da terça — o job sai de 12 tarefas e chega a 15.

---

## 🧠 A ideia da noite: ML é camada, não projeto

A tentação, quando entra machine learning num projeto de dados, é abrir um
repositório novo, um notebook solto, um ambiente à parte. É assim que nasce o
modelo que ninguém consegue colocar em produção.

Aqui ML entra como **mais uma camada do mesmo pipeline**: mesmo bundle, mesmo
job, mesmos testes que quebram, mesma auditoria de metadado.

```
raw → bronze → silver ×4 → dimensões → fato → marts → testes
                                             ├→ métricas → auditoria
                                             └→ ml_features → ml_modelo → ml_fila
```

---

## 📋 Os três prompts

Cada um num arquivo próprio, com o prompt copiável, os slides que o
acompanham, o que falar enquanto o Claude Code trabalha, como validar ao vivo
e uma tabela **"se der errado"**.

| # | Entrega | Slides | Arquivo |
|---|---|---|---|
| 1 | **Features** — o que descreve um cliente | 16–22 | [`prompt-01-features.md`](prd/prompt-01-features.md) |
| 2 | **Modelo e MLflow** — o baseline que choca | 23–37 | [`prompt-02-modelo.md`](prd/prompt-02-modelo.md) |
| 3 | **A fila e o agente** — os 200, com motivo | 38–45 | [`prompt-03-fila-e-agente.md`](prd/prompt-03-fila-e-agente.md) |

### Prompt 1 · Features — *o que descreve um cliente*

Transforma o fato de vendas, que tem uma linha por **item**, em uma tabela com
uma linha por **cliente** e 20 colunas de comportamento: RFM, ritmo, CRM e mix.
Tudo sai de UMA função `montar_features(referencia)`, chamada duas vezes com
datas diferentes — é o que garante que treino e score nunca divirjam.

> **Entrega:** `gold.features_treino` (corte 01/08, com o alvo `comprou_em_7d`)
> e `gold.features_cliente` (corte 31/08, sem alvo — é quem vai ser pontuado).
> **O número da vez:** a taxa base de **10,1%** — vinte de cada duzentas
> ligações às cegas viram pedido.

### Prompt 2 · Modelo e MLflow — *o baseline que choca*

Mede as respostas da sala **antes** de treinar qualquer coisa, treina, registra
o modelo no Unity Catalog e pontua os 3.000 clientes. O treino tem três
`assert` que interrompem a tarefa: o modelo precisa ganhar do baseline, não
pode ser bom demais (vazamento) e a fila precisa se pagar.

> **Entrega:** o modelo `gold.propensao_compra` no catálogo com alias `@prod`,
> mais `gold.score_propensao`, `gold.modelo_metricas` e
> `gold.calibragem_holdout`.
> **O número da vez:** **`lift_top200`** — não o AUC. É ele que responde a
> pergunta do diretor.

### Prompt 3 · A fila e o agente — *os 200, com motivo*

Cruza o score com a carteira de cada vendedor e escreve a lista da semana em
português. A fila é **global** — os 200 maiores scores da base inteira — e só
depois é dividida por vendedor: quem tem carteira quente recebe mais, quem tem
carteira fria recebe menos, e é isso que está certo. Cria também as quatro
funções que o agente consulta, e ensina o Genie a nunca inventar número.

> **Entrega:** `gold.fila_semanal` com `motivo` e `sugestao` por cliente, mais
> `priorizar_carteira`, `contexto_cliente`, `sugerir_produtos` e
> `checar_disponibilidade` como funções do Unity Catalog.
> **O número da vez:** **200 contatos entre ~42 vendedores, de 2 a 10 cada** —
> e três testes que quebram o job se a fila vier torta.

O roteiro da noite, com cronograma e as falas:
[`3-prompts-noite-3.md`](prd/3-prompts-noite-3.md).

**Para seguir ao vivo, com onde clicar em cada passo:**
[`passo-a-passo/`](passo-a-passo) — um arquivo curto por prompt, para deixar
aberto numa aba ao lado do Claude Code.

**Para ensaiar quantas vezes quiser:**
[`99-limpar-aula-03.md`](prd/99-limpar-aula-03.md) apaga só a noite 3 e devolve
o ambiente ao fim da noite 2.

```bash
bash prd/99-limpar-aula-03.sh <perfil>            # simula
bash prd/99-limpar-aula-03.sh <perfil> --apagar   # apaga
```

---

## 🧱 O chão conceitual (slides 10–15)

Antes do primeiro prompt, a noite para em dois blocos curtos. Eles existem
porque os slides seguintes usam "feature", "rótulo", "holdout" e "AUC" o tempo
inteiro, e ninguém combinou o significado.

### A matéria-prima: a gold de ontem (10–12)

Três queries no SQL Editor, ao vivo:

| Slide | O que aparece na tela |
|---|---|
| 10 | `SELECT COUNT(*), SUM(receita) FROM gold.fato_vendas` → **191.080 linhas · R$ 102.303.828,05** |
| 11 | As dez sujeiras nos números do dataset: 3.443 datas em `dd/mm/aaaa`, 40 clientes duplicados, 957 cancelados com `valor_total = 0`, 2.327 devoluções negativas |
| 12 | O item cru soma **R$ 105.890.448,42**; a gold soma **R$ 102.303.828,05**. A diferença é **R$ 3.586.620,37 de receita que nunca existiu** |

> O slide 12 é o que amarra as duas noites: a feature `valor_total` do prompt 1
> sai dessa soma. **Feature errada não dá erro — dá fila errada.**

### As premissas de ML (13–15)

| Slide | A ideia |
|---|---|
| 13 | **O que é um modelo:** não é regra que alguém escreveu; é uma função ajustada olhando exemplos onde a resposta já é conhecida. Ele não descobre *por que* o cliente compra — descobre o que andou junto com "comprou" |
| 14 | **O vocabulário:** feature (X) é o que se sabia até 31/07, rótulo (y) é o que aconteceu depois, treino é o que ele vê, teste é o que ele não vê. *Nota tirada no treino é prova com o gabarito na mão* |
| 15 | **As cinco premissas:** o passado se repete · o futuro não entrou nas features · uma linha por cliente, sem influência entre eles · quem eu pontuo se parece com quem eu treinei · o modelo ordena, não explica causa |

**Premissa não é detalhe teórico: é a lista do que conferir quando o modelo
começar a errar.** Mudou a política comercial? Quebrou a primeira — e é por
isso que o modelo mora num pipeline agendado, não num notebook.

### E se a sala perguntar por Poisson (slide 25)

Vai perguntar, e a resposta está num slide próprio:

| Caminho | Por que não foi o escolhido |
|---|---|
| **Regressão logística** | Assume relação de linha reta. Atraso relativo de 1,5 é ouro e de 5 é cliente perdido — não é reta |
| **Poisson / BG-NBD + Monte Carlo** | É o mais fiel ao ciclo de reposição: cada cliente compra a uma taxa λ própria e, a cada compra, pode "morrer" como cliente. Diz até *quantos* pedidos. Mas lê só recência e frequência — CRM, visitas e mix ficam de fora |
| **Uplift** | Responde "quem muda de comportamento **se** eu ligar", que é a pergunta certa quando há desconto na mesa. Exige teste A/B: metade da lista sem contato |
| **Árvore** (o escolhido) | Acha sozinha que atraso perto de 1,5 é ouro, aceita as 20 colunas como vieram e cabe em três linhas ao vivo |

Nenhum está errado. O critério foi: **qual usa todo o dado que a gente limpou
ontem.**

---

## ⚡ O momento da noite

Antes de qualquer código, a pergunta vai para a sala:

> **"Você tem 200 ligações e 3.000 clientes. Qual coluna você ordena?"**

As duas respostas de sempre são *"quem parou de comprar"* e *"quem compra
mais"*. No prompt 2 as duas são medidas na frente de todo mundo — e a primeira
vem **abaixo de jogar uma moeda**.

**A intuição comercial não está imprecisa — está invertida.** Distribuição
funciona por ciclo de reposição: quem acabou de receber a mercadoria é
justamente quem não compra agora. Ninguém tinha medido.

| Dos 200 abordados, quantos compram | medido |
|---|---|
| Ligar aleatório | 20 |
| **Ligar para quem sumiu há mais tempo** | **0** |
| Ligar para os maiores | 44 |
| **Ligar para os 200 de maior score** | **75 — 3,7×** |

Dataset com `seed 42`, corte `2026-08-01`, janela de **7 dias** — a mesma
semana da ligação — e score *out-of-fold* sobre os 2.815 clientes.

**É o melhor momento da noite e ele acontece no prompt 2.** Não entregue antes.

---

## 🎯 As quatro ideias que a noite defende

### 1 · A feature que vale dinheiro não vem de biblioteca

`recencia_dias` está em qualquer tutorial. **`atraso_relativo`** — recência
dividida pelo intervalo médio *do próprio cliente* — não está em nenhum, porque
depende de saber como distribuição funciona.

Um cliente que compra a cada 7 dias e sumiu há 20 está em risco. Um que compra
a cada 90 e sumiu há 20 está normal. **A recência não distingue os dois** — e
ordenar por ela coloca os dois na mesma posição da fila.

### 2 · Vazamento de dado não parece erro — parece sucesso

Se a feature enxergar o que aconteceu depois do rótulo, o AUC beira 1,0 e você
manda print no grupo. Três meses depois o modelo acerta menos que o estagiário.

Três defesas, todas estruturais:

| Defesa | Onde |
|---|---|
| Uma função só, com a data por parâmetro | `montar_features(referencia)` |
| Um teste que desconfia do sucesso | AUC ≥ 0,99 **quebra o job** |
| Uma coluna que registra o corte | `_referencia` nas duas tabelas |

### 3 · A métrica que vai para a reunião não é o AUC

AUC é métrica de quem treina. O diretor pergunta **quantos dos 200 compraram** —
e a resposta é 75 contra 20 —
e isso tem nome: `lift_top200`. É a métrica que o pipeline versiona a cada
treino, ao lado do AUC, porque é ela que responde a pergunta que pagou o
projeto.

### 4 · Score não é decisão

`0,8412` não é uma ação. A `fila_semanal` traduz para a língua de quem vai
ligar:

> *"Compra a cada 8 dias e está há 26 sem pedido. Risco de perder."*
>
> *"Comprou o lançamento no mês passado. Alta chance de repetir."*

Modelo que não explica não é usado: fica um mês na tela e some. **O último
metro é onde os projetos de ML morrem**, e é o que o prompt 3 resolve.

---

## 🧪 Notebooks para conferir o resultado

Para abrir **depois** que o pipeline rodou. São de leitura — não alteram nada.

| Notebook | Para quê |
|---|---|
| [`01-o-que-o-modelo-vale.sql`](notebooks/01-o-que-o-modelo-vale.sql) | Seis perguntas na ordem em que uma pessoa cética faria. Começa por "de 200 ligações, quantas viram pedido a mais?" |
| [`02-o-vazamento-de-dado.py`](notebooks/02-o-vazamento-de-dado.py) | Comete o erro de propósito, mede, e conserta. Um filtro a menos e o AUC vira **~0,9998** |

O `02` é o mais importante para levar ao vivo se sobrar tempo: ele treina dois
modelos idênticos, um com o filtro de data e outro sem.

| Modelo | AUC medido |
|---|---|
| honesto | ~0,867 |
| vazado | **~0,9998** |

**0,9998 não é "um modelo muito bom" — é um modelo que leu a resposta.** Ele
ordenou os 704 clientes do teste praticamente sem errar porque **1.147 deles
tinham recência negativa**: a última compra era *posterior* à data de corte.
Não aprendeu nada — e passaria em qualquer revisão de código.

---

## 🗂️ Onde o código mora

O bundle é o **mesmo da noite 2** — o aluno continua no projeto que já tem:

```
aulas/aula-02-engenharia-de-dados/rotaperfume/
└── src/ml/
    ├── 11-features.py    uma função, dois cortes, duas tabelas
    ├── 12-modelo.py      baseline → treino → MLflow → UC → score
    └── 13-fila.sql       os 200, o motivo em português e as 4 ferramentas
```

### Como rodar

```bash
cd aulas/aula-02-engenharia-de-dados/rotaperfume
databricks bundle validate --target dev --profile <perfil>
databricks bundle deploy   --target dev --profile <perfil>
databricks bundle run rotaperfume_pipeline --target dev --profile <perfil>
```

> O `--profile` é o mesmo que você escolheu na noite 2.

---

## 🎬 Os slides

45 slides, gerados por código, no mesmo design das noites 1 e 2:

```bash
uv venv --python 3.12 /tmp/pptx && uv pip install --python /tmp/pptx/bin/python python-pptx
/tmp/pptx/bin/python aulas/aula-03-ciencia-de-dados/slides/gerar_slides.py
```

| Slides | Bloco | Min |
|---|---|---|
| 1–7 | A pergunta dos 200 | 14 |
| 8–9 | O plano da noite: três prompts, três deploys | 4 |
| 10–12 | A gold de ontem — a matéria-prima, com query na tela | 6 |
| 13–15 | **As premissas de ML** — o que é modelo, o vocabulário, o que assumimos | 7 |
| 16–22 | Feature engineering e as features · **prompt 1 rodando** | 19 |
| 23–30 | O modelo, o boosting, as alternativas, o AUC e o vazamento | 16 |
| 31–37 | **MLflow** — o que é, a anatomia de um run, por que aqui · **prompt 2 rodando** | 16 |
| 38–42 | A fila e o agente · **prompt 3 rodando** | 18 |
| 43–45 | Fecho | 5 |

**Total: ~105 min de conteúdo técnico.** Boa parte disso é fala enquanto o
Claude Code trabalha — os slides de conceito não são intervalo, são o que
preenche os três deploys.

### O deck curto (~85 min)

Se o relógio apertar, corte nesta ordem. Nenhum deles quebra o argumento:

| Slide | Por que sai primeiro |
|---|---|
| 10 e 11 | Fique só com o 12, que é o que amarra a limpeza na feature |
| 27 · Por que árvore e não Poisson | Vale mais como resposta quando a pergunta vem da sala |
| 35 · A anatomia de um run | Mostre a tela do MLflow no lugar — é mais convincente |
| 39 · Batch ou tempo real | Também é resposta de Q&A |
| 26 · Como a árvore aprende | Só se for necessário: é o slide que tira o mistério do `fit()` |

---

## ⚠️ Armadilhas medidas contra o workspace

Estas custaram tempo na preparação e **quase todas são específicas do Free
Edition**. Estão documentadas dentro do prompt onde aparecem.

1. **`mlflow.pyfunc.spark_udf` não funciona no serverless.** Levanta
   `InvalidVersion: '18.x-aarch64-photon-scala2'` — e é o caminho que toda a
   documentação recomenda. A saída é `load_model` + pandas.

2. **XGBoost treina, registra e não carrega de volta.** Conflito com o
   scikit-learn 1.6.1 do serverless (`__sklearn_tags__`). O pior tipo de erro:
   aparece **uma tarefa depois**. Use `HistGradientBoostingClassifier`.

3. **`mlflow.set_experiment` não cria a pasta pai.** O erro é
   `BAD_REQUEST: For input string: "None"` e não menciona pasta nenhuma.
   Resolve com `WorkspaceClient().workspace.mkdirs(...)` antes.

4. **`DECIMAL` não serializa em JSON.** A gold usa `DECIMAL(18,2)`; sem
   `.cast("double")` nas features, o registro do modelo morre.

5. **`pyfunc.predict()` devolve a classe, não a probabilidade.** A coluna
   inteira vira zeros e uns e a fila vira sorteio. Use `predict_proba`.

6. **Free Edition não tem endpoint de modelo próprio.** Por isso o consumo é
   batch. O que, para uma pergunta que muda uma vez por semana, é a arquitetura
   correta de qualquer forma.

---

## 🎬 O fechamento

> *"Segunda a gente escreveu uma query que quebrou por causa de data em dois
> formatos. Terça aquilo virou camada. Hoje o mesmo pipeline parou de responder
> o que aconteceu e passou a dizer para quem ligar na segunda de manhã.*
>
> *Dashboard descreve o passado. Modelo prevê o futuro. Agente diz o que fazer.*
>
> *E vocês construíram junto. Não assistiram."*
