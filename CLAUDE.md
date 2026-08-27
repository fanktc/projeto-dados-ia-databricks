# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## O que é este repositório

Material e código da **Imersão Jornada de Dados** (24 a 27 de agosto de 2026): construir do zero,
ao vivo em 4 noites, a área de dados e vendas da **Rota do Perfume** — distribuidora B2B fictícia
de perfumaria árabe. Todo o conteúdo é em português e escrito para ser acompanhado ao vivo.

O repositório é organizado **uma pasta por noite**, no mesmo esquema do
`data-engineering-roadmap`: cada aula é autocontida, com README próprio, KPIS
quando faz sentido e exemplos numerados em progressão.

| Pasta | O que é |
|---|---|
| `aulas/aula-01-databricks-sql/` | Noite 1: setup, ingestão bronze, 6 exemplos progressivos, slides, roteiro do Genie |
| `aulas/aula-02-engenharia-de-dados/` | Noite 2: **6 prompts, 6 deploys**. O bundle `rotaperfume/` nasce vazio e vira raw → bronze → silver → gold → dashboard → Genie |
| `aulas/aula-02-engenharia-de-dados/prd/` | Os 6 prompts (+ o reset 00), o `CLAUDE.md` do projeto e o roteiro da noite |
| `aulas/aula-02-engenharia-de-dados/slides/` | `gerar_slides.py` — os slides como código, no design da noite 1 |
| `aulas/aula-03-ciencia-de-dados/` | Noite 3 (**"Quais 200?"**): **3 prompts, 3 deploys**. O mesmo bundle da noite 2 ganha `src/ml/` e o job vai de 12 para 15 tarefas |
| `aulas/aula-03-ciencia-de-dados/prd/` | Os 3 prompts da noite 3, o roteiro e o `99-limpar-aula-03` (apaga só a noite 3) |
| `aulas/aula-03-ciencia-de-dados/notebooks/` | Notebooks de conferência do resultado (leitura), incluindo a demonstração de vazamento de dado |
| `aulas/aula-04-app-e-genie/` | Noite 4 (**"E quem não escreve SQL?"**): **3 prompts, 3 deploys**. O Genie da direção, o Databricks App com a fila dos 200 e o retorno da ligação voltando para a gold |
| `aulas/aula-04-app-e-genie/prd/` | Os 3 prompts da noite 4, o roteiro e o `99-limpar-aula-04` |
| `aulas/aula-04-app-e-genie/rotaperfume-direcao/` | O Databricks App (AppKit — Node/TypeScript/React), com **bundle próprio** e target `default` |
| `material/` | PRD (a especificação canônica das 4 noites), gerador do dataset, zip de referência, slides antigos |
| `scripts/run_sql.py` | Executa um `.sql` no warehouse, statement por statement |
| `dados/` | Dataset gerado, **não versionado**. `python3 material/gerar_dataset.py --saida ./dados --seed 42` |

**A aula 04 não é "deploy":** deploy não é etapa de fim de projeto, é o que
acontece toda vez que você termina algo — por isso a noite 2 faz seis. A
**aula 03 foi reescrita** em torno de uma pergunta só — *"tenho 3.000
clientes e 200 ligações por semana; quais 200?"* — e feita até o fim em três
prompts: features, modelo/MLflow, fila e agente. O código dela vive dentro do
bundle da noite 2 (`rotaperfume/src/ml/`): ML é mais uma camada do mesmo
pipeline, não um projeto à parte.

A **aula 04** responde o que as três anteriores deixam aberto: *"tudo isso só
abre no SQL Editor — e quem não escreve SQL?"*. Ela não cria dado de análise
novo; consome `gold.fila_semanal` e entrega duas portas (um Genie curado por
audiência e um Databricks App) mais o **caminho de volta**:
`gold.retorno_ligacao`, escrita pelo app, que é o rótulo de treino da semana
seguinte.

Ao criar exemplos novos para a aula 01, siga o padrão: `exemplo-NN-tema.sql`,
com cabeçalho declarando conceito, pergunta de negócio e conexão com a aula
seguinte. Seis a oito exemplos por aula — mais que isso não cabe na noite.

## Databricks

- Trabalho relacionado a Databricks passa pelas skills: carregue `databricks-core` (skill pai)
  **antes** de qualquer ação, mais a skill do produto correspondente (`databricks-dabs`,
  `databricks-pipelines`, `databricks-jobs`, etc.).
- **Nunca escolha um profile automaticamente.** Passe `--profile <nome>` e deixe o usuário decidir.
  Profiles disponíveis em `.databrickscfg`: `DEFAULT`, `dbc-755bf06d-df36`, `jornada`, `Jornada2`,
  `grid_intelligence`, `projeto-dados-ia`.
- O ambiente-alvo é **Databricks Free Edition (serverless)**: nada que exija cluster dedicado.

### Catálogo

`lakehouse_rotaperfume`, schemas `bronze`/`silver`/`gold`. O nome **não tem underscore**
entre "rota" e "perfume" — se algum documento escrever `lakehouse_rota_perfume`, está errado.

O catálogo é recriado do zero pelos 6 prompts da noite 2. `prd/00-reset.sh` apaga tudo
(catálogo, bundle e código local) para provar que os seis bastam.

Existe também um catálogo `rota_perfume` antigo no workspace, de execuções anteriores;
o material não aponta mais para ele.

Não existe compute clássico na Free Edition: tudo roda no SQL Warehouse serverless
`Serverless Starter Warehouse`. `python3 scripts/run_sql.py <arquivo.sql>` executa um `.sql`
statement por statement (a CLI só aceita uma por chamada, e um statement que começa com
comentário `--` seria confundido com flag se passado como argumento — por isso o runner usa stdin).
Passe `--continuar` em arquivos que contêm query que falha de propósito.

## Comandos

### Bundle da noite 2 (`aulas/aula-02-engenharia-de-dados/rotaperfume/`)

```bash
cd aulas/aula-02-engenharia-de-dados/rotaperfume

bash scripts/criar-catalogo.sh <perfil>       # o catálogo (SQL — a API do UC não cria no Free Edition)
databricks bundle validate --target dev  --profile <perfil>
databricks bundle deploy   --target dev  --profile <perfil>   # dev é o target default
bash scripts/subir-raw.sh  <perfil>           # os CSVs para o Volume — DEPOIS do deploy
databricks bundle run rotaperfume_pipeline --target dev --profile <perfil>
```

A ordem importa duas vezes: o catálogo antes do deploy (que cria os schemas), e o
deploy antes do upload (que precisa do Volume existindo).

Para testar UMA tarefa sem rodar o job inteiro (3m30 → 35s):

```bash
bash scripts/rodar-tarefa.sh <perfil> ml_features
```

Cada tarefa serverless paga o próprio tempo de partida, e o job inteiro paga
treze vezes. **É o padrão do projeto ao vivo:** rode a tarefa enquanto
constrói, e o `bundle run` completo só no fim, para mostrar o DAG verde.

Para zerar tudo e recomeçar do nada:

```bash
bash aulas/aula-02-engenharia-de-dados/prd/00-reset.sh <perfil>            # simula
bash aulas/aula-02-engenharia-de-dados/prd/00-reset.sh <perfil> --apagar   # apaga
```

### Os 12 prompts (`PROMPTS.md`)

`PROMPTS.md` na raiz junta os doze prompts das noites 2, 3 e 4 em sequência. O
texto **não é copiado à mão**: sai da seção `## O prompt` de cada arquivo em
`aulas/*/prd/`. Depois de editar qualquer prompt, regere:

```bash
python3 scripts/gerar_prompts.py
```

As partes fixas (cabeçalho, os dois intervalos entre noites e o rodapé) ficam
em `scripts/prompts-*.md` — edite lá, nunca direto no `PROMPTS.md`, que é
gerado.

### Slides

```bash
uv venv --python 3.12 /tmp/pptx && uv pip install --python /tmp/pptx/bin/python python-pptx
/tmp/pptx/bin/python aulas/aula-02-engenharia-de-dados/slides/gerar_slides.py
```

### Dataset (`material/`)

```bash
python gerar_dataset.py --saida ./dados --seed 42   # sem dependências externas
unzip material/dados-rota-do-perfume.zip                     # ou apenas descompacte o pronto (~14 MB)
```

## Arquitetura do bundle `rotaperfume/`

Um bundle só, que na aula nasce vazio e ganha uma camada por prompt. Seis deploys.

```
databricks.yml            targets dev e prod, variáveis catalog e warehouse_id
scripts/
  criar-catalogo.sh       CREATE CATALOG via SQL (a API do UC recusa no Free Edition)
  subir-raw.sh            databricks fs cp dos CSVs para o Volume
resources/
  catalogo.yml            schemas bronze/silver/gold + volume bronze.raw
  pipeline.job.yml        rotaperfume_pipeline — 12 tarefas, agendado, serverless
  dashboard.dashboard.yml + dashboard-comercial.lvdash.json
  genie.genie_space.yml   + comercial.geniespace.json
src/
  raw/conferencia.py      notebook: os 10 arquivos chegaram? grava bronze._raw_arquivos
  bronze/ingestao.py      notebook: CSV → Delta, tudo texto, sem limpar nada
  silver/01..04*.sql      sql_task: a limpeza, com CONSTRAINT declarada
  gold/05..10*.sql        sql_task: dimensões, fato, marts, 9 testes, views, auditoria
```

O DAG do job é a tela que conta a história da noite:

```
raw_conferencia → bronze_ingestao → silver ×4 (paralelo) → gold_dimensoes
  → gold_fato_vendas → gold_marts → testes_de_qualidade
                                  → metricas_de_negocio → auditoria_de_metadado
```

Camada em Python (notebook serverless) onde há arquivo e loop; camada em SQL
(`sql_task` no warehouse) onde há transformação. Nenhum wheel, nenhum build —
o deploy é de segundos, o que importa quando são seis ao vivo.

**Os testes quebram o job de propósito.** `raise_error()` dentro de `CASE WHEN`
interrompe a tarefa. Melhor o dashboard ficar com o dado de ontem do que com o
dado errado de hoje.

## Domínio: Rota do Perfume

O contrato de dados, as 10 "sujeiras propositais", o comportamento esperado dos números e as
convenções de nomenclatura estão em `material/CLAUDE.md` e no PRD. Os pontos que mudam decisões
mesmo fora da pasta `material/`:

- **A sujeira nos dados é conteúdo, não bug.** Nunca "conserte" `gerar_dataset.py`. Limpar é o
  exercício da noite 2, e acontece na camada silver — a bronze preserva o dado como veio.
- **Seed fixa (42).** Nunca introduza aleatoriedade em análise: todo aluno precisa chegar ao
  mesmo número.
- **Sazonalidade é invertida.** O varejo compra antes da data, então o pico da distribuidora é o
  mês *anterior* à data comemorativa (abril, junho, outubro; dezembro e janeiro são vale).
- Nomes de tabela e coluna em **snake_case e português**, iguais aos do CSV.
- Referencie tabelas pelo caminho completo (`<catalogo>.silver.pedidos`).
- Código e comentários escritos para quem assiste ao vivo pela primeira vez: prefira SQL legível
  a SQL esperto.

## ML na Free Edition — o que NÃO funciona

Medido contra o workspace. Não tente estes caminhos: os quatro primeiros falham,
e três deles só falham na tarefa seguinte.

- **`mlflow.pyfunc.spark_udf` não roda no serverless.** `InvalidVersion:
  '18.x-aarch64-photon-scala2'`. Use `mlflow.sklearn.load_model` + pandas.
- **XGBoost treina e registra, mas não carrega de volta** (`__sklearn_tags__`,
  conflito com scikit-learn 1.6.1). Use `HistGradientBoostingClassifier`.
- **`mlflow.set_experiment` não cria a pasta pai.** Erro:
  `BAD_REQUEST: For input string: "None"`. Crie antes com
  `WorkspaceClient().workspace.mkdirs(...)`.
- **`pyfunc.predict()` devolve a classe, não a probabilidade.** Para score use
  `predict_proba()`.
- **Não há endpoint de modelo próprio** — só os Foundation Models publicados.
  O consumo do modelo é batch, gravando `gold.score_propensao`.
- O serverless traz **MLflow 2.22**: `log_model(..., artifact_path=...)`, nunca
  o `name=` do MLflow 3.
- A gold usa `DECIMAL(18,2)`; features precisam de `.cast("double")` ou o
  registro do modelo morre com `Object of type Decimal is not JSON serializable`.

Convenções de ML do projeto: corte de treino **2026-08-01**, janela do rótulo de
**7 dias** (a mesma semana da fila de ligação — com 30 dias a taxa base sobe de
10,1% para 39,9% e o ganho do modelo deixa de fazer sentido para o comercial),
`random_state=42`, e nada de `current_date()` — o "hoje" do dataset
é **2026-08-31**.

A noite 3 cria seis tabelas na gold — `features_treino`, `features_cliente`,
`score_propensao`, `modelo_metricas`, `calibragem_holdout` e `fila_semanal` —
mais o modelo `gold.propensao_compra` no UC e quatro funções-ferramenta. A
métrica que vai para a reunião é **`lift_top200`**, não o AUC.

## Databricks Apps (noite 4) — o que foi medido

Apps **funciona** na Free Edition. Medido contra o workspace em 27/08:

- `databricks apps init` (scaffold AppKit + npm install): **~60s**.
- **Primeiro** `apps deploy` (cria o compute): **3m44s**. Redeploy: **1m04s**.
- **`bundle deploy` NÃO sobe app** — cria com `no_compute` e deixa parado, sem
  URL. Para app é `databricks apps deploy`, e o target do bundle gerado pelo
  `apps init` chama-se **`default`**, não `dev`.
- **O app é um usuário do Unity Catalog.** `permission: CAN_USE` no warehouse
  dá acesso ao compute, não ao dado: sem `GRANT USE CATALOG` + `USE SCHEMA` +
  `SELECT` para o service principal, toda tela carrega vazia. O SP muda a cada
  app criado — leia com `databricks apps get`, nunca copie.
- Escrita é `GRANT MODIFY` **numa tabela só** (`gold.retorno_ligacao`), via
  `getExecutionContext().client.statementExecution.executeStatement`.
- `npm run typegen` **exige o warehouse ligado**; parado, degrada para
  `OFFLINE` e gera `{}` como tipo, quebrando o `tsc` longe da causa real.
- `useAnalyticsQuery` **não tem `refetch`**: para recarregar depois de escrever,
  use um parâmetro que não filtra nada (`recarga`) e mude o valor.
- **O typegen tipa como `number` o que o runtime entrega como `string`** (o
  warehouse serializa todo número como string no JSON). Sem `Number()`:
  `toLocaleString` não formata, `+` concatena e um `z.number()` no servidor
  recusa o id que a tela mandou. Use `z.coerce.number()` do lado do servidor.
- Tabela larga precisa de `table-fixed` + largura por coluna; sem isso as
  células transbordam e uma escreve por cima da outra.
- `Unexpectedly failed to update app's compute size` é transitório no Free
  Edition — rode o `apps deploy` de novo.
- **Lakebase não está disponível** (`postgres list-projects` volta vazio). Por
  isso a escrita vai para tabela Delta via SQL warehouse.
