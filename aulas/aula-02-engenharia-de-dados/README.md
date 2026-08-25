# 🏗️ Dia 2: Engenharia de dados | Imersão Jornada de Dados

Ontem a query quebrou por causa das datas em dois formatos, e a gente resolveu
no braço com um `try_to_date` dentro do `SELECT`. Funcionou — para uma query.

Hoje isso vira **camada**: escrito uma vez, testado, agendado, e todo mundo que
consultar o dado depois já pega ele limpo.

> 📺 **Gravação da aula:** https://www.youtube.com/watch?v=0KRcn4ZIDPg
>
> **Promessa da noite:** o projeto passa a rodar sozinho.
> **Pergunta da noite:** *"Como faço para não resolver o mesmo problema toda vez?"*
> **Formato:** [6 prompts, 6 deploys](prd/6-prompts-noite-2.md). O projeto inteiro
> nasce de um catálogo vazio.

---

## 🧠 A ideia da noite: deploy é rotina, não evento

A aula 4 original era "deploy". Ela morreu, e por um bom motivo: deploy não é
uma etapa no fim do projeto. É o que acontece **toda vez que você termina
alguma coisa**.

Por isso ele aparece seis vezes aqui. Um bundle que nasce vazio e ganha uma
camada por prompt — o mesmo job começa com **uma** tarefa e termina com **doze**:

```
prompt 1   raw
prompt 2   raw → bronze
prompt 3   raw → bronze → silver ×4
prompt 4   raw → bronze → silver ×4 → dimensões → fato → marts → testes
prompt 5   + dashboard versionado no bundle
prompt 6   + views de negócio, auditoria de metadado e Genie
```

A tela que conta essa história é o DAG do job. Abra depois de cada deploy.

---

## 🧰 Passo a passo — do zero até o primeiro deploy

Tudo acontece no terminal. Uma aula de Databricks **sem abrir a tela do
Databricks**.

> 📺 **O passo a passo abaixo saiu deste workshop:**
> [Databricks + IA: o workflow completo de desenvolvimento com Claude Code (DABs, MCP, AI Dev Kit)](https://www.youtube.com/watch?v=0l-DZkniRSg).
> Se algum passo aqui não fizer sentido, lá ele está sendo executado ao vivo.

### 0 · Confira o que já está instalado

```console
➜  EngenhariaDatabricks git:(main) databricks --version
Databricks CLI v1.13.0
➜  EngenhariaDatabricks git:(main) python --version
Python 3.11.15
➜  EngenhariaDatabricks git:(main) claude --version
2.1.245 (Claude Code)
➜  EngenhariaDatabricks git:(main) uv --version
uv 0.6.3
➜  EngenhariaDatabricks git:(main) gh --version
gh version 2.49.0
```

| Ferramenta | Mínimo | Se faltar |
|---|---|---|
| `databricks` | **v0.205+** (aqui: v1.13.0) | `brew tap databricks/tap && brew install databricks` |
| `python` | **3.10 a 3.12** | Nunca 3.13 — bibliotecas do Databricks ainda quebram nela |
| `claude` | qualquer | [claude.com/claude-code](https://claude.com/claude-code) |
| `uv` | qualquer | `brew install uv` |
| `gh` | qualquer | `brew install gh` |

> Se `databricks --version` mostrar algo abaixo de 0.205, você está na **legacy
> CLI** (a antiga, em Python). Desinstale e instale de novo pelo tap.

---

### 1 · Autenticar — e o erro que quase todo mundo vê primeiro

A tentação é já sair criando o projeto. Ele reclama:

```console
➜  EngenhariaDatabricks git:(main) databricks bundle init
Error: error getting token: cache: stored credentials from older CLI versions
are no longer used; run `databricks auth login` to sign in again, or set
DATABRICKS_AUTH_STORAGE=plaintext to keep using the file cache
```

**Não é bug seu.** A CLI mudou onde guarda credencial: o que estava no cache
antigo não vale mais. A correção é literalmente o que a mensagem manda:

```console
➜  EngenhariaDatabricks git:(main) databricks auth login
Using profile: + Create a new profile
Databricks profile name [DEFAULT]: EngenhariaDatabricks
Opening login.databricks.com in your browser...
Profile EngenhariaDatabricks was successfully saved
```

Confira que ficou válido antes de seguir:

```console
➜  EngenhariaDatabricks git:(main) databricks auth profiles
Name                  Host                                            Valid
EngenhariaDatabricks  https://dbc-xxxxxxxx.cloud.databricks.com       YES
```

> **Daqui para frente, sempre passe `--profile`.** Nunca deixe implícito — é
> assim que um dia você faz deploy em produção sem querer.

---

### 2 · Criar o projeto

```console
➜  EngenhariaDatabricks git:(main) databricks bundle init
Template to use [default-python]: default-python

Unique name for this project [my_project]: rotaperfume
Initial language for this project [Python]: Python
Include a job that runs a notebook [yes]: no
Include an ETL pipeline [yes]: no
Include a sample Python package that builds into a wheel file [yes]: no
Default catalog for any tables created by this project: lakehouse_rotaperfume
Use serverless compute [yes]: yes

✨ Your new project has been created in the 'rotaperfume' directory!
```

**Entre no projeto** — todo comando daqui para frente roda de dentro dele:

```console
➜  EngenhariaDatabricks git:(main) cd rotaperfume
➜  rotaperfume ls
AGENTS.md  CLAUDE.md  README.md  databricks.yml  fixtures  pyproject.toml  tests
```

<details>
<summary><b>Pulando as perguntas</b> — a versão não-interativa, para repetir sem digitar</summary>

Útil quando você já rodou uma vez, ou quando precisa refazer rápido ao vivo.
Crie um `respostas.json`:

```json
{
  "project_name": "rotaperfume",
  "include_job": "no",
  "include_pipeline": "no",
  "include_python": "no",
  "serverless": "yes",
  "default_catalog": "lakehouse_rotaperfume",
  "personal_schemas": "no, I will customize the schema configuration later in databricks.yml"
}
```

E rode:

```console
➜  EngenhariaDatabricks databricks bundle init default-python \
     --config-file respostas.json --profile EngenhariaDatabricks
✨ Your new project has been created in the 'rotaperfume' directory!
```

> O valor de `personal_schemas` é comprido assim mesmo — a CLI valida contra o
> texto exato do enum e recusa um `"no"` simples.

</details>

Três respostas que importam:

- **`no` nos três "Include a sample…"** — a gente vai escrever os nossos. O
  código de exemplo do template lê `samples.nyctaxi.trips` e só atrapalha.
- **`yes` em serverless** — não é preferência. O **Free Edition só permite
  serverless**; se responder `no`, o deploy falha por falta de compute.
- **O catálogo** já entra como variável no `databricks.yml`.

O que o Asset Bundle traz de brinde: dev e prod isolados, testes unitários,
esteira de CI/CD e Terraform por baixo. É a engenharia de software entrando na
engenharia de dados.

> ⚠️ **O template nasce com `mode: development` no target `dev`.** Isso prefixa
> o nome dos recursos com `[dev seu_usuario]` — **inclusive os schemas do Unity
> Catalog**, que virariam `dev_seunome_bronze` e quebrariam todo o SQL da noite.
> O **prompt 1** troca isso por `presets: trigger_pause_status: PAUSED`. Não é
> detalhe: é a armadilha que mais custa tempo aqui.

---

### 3 · O ambiente Python

```console
➜  rotaperfume uv venv --python 3.12 --seed
➜  rotaperfume source .venv/bin/activate
➜  rotaperfume uv sync
```

O `--seed` já instala o `pip` junto, e evita dor de cabeça depois.

> **É o erro nº 1 de quem tenta em casa:** instalar tudo no Python 3.13 e nada
> funcionar. Fique entre 3.10 e 3.12.

---

### 4 · Versionar antes de a IA escrever a primeira linha

```console
➜  rotaperfume git init && git add . && git commit -m "first commit"
➜  rotaperfume gh repo create
```

Não é burocracia. Se a IA vai escrever código, você precisa de `git diff` para
revisar e de `git revert` para desfazer.

---

### 5 · Skills e MCP — o AI Dev Kit

Pesquise **"AI Dev Kit Databricks"** e siga o quickstart de instalação. Ele
pergunta três coisas:

| Pergunta | Resposta |
|---|---|
| Qual IDE? | Claude Code |
| Instalação global ou de projeto? | **Projeto** — cada projeto tem o contexto dele |
| Quais grupos de skills? | Todos (~40 skills: engenharia de dados, BI, ML, apps) |

**A diferença que vale explicar:** *skill* é **injeção de conhecimento** — o
Claude passa a saber como o Databricks funciona. *MCP* é **ação** — é o que
conecta de verdade no workspace e executa.

```console
➜  rotaperfume claude
> /mcp
```

Se o MCP não aparecer na lista: **reinicie o Claude Code**. É quase sempre isso.

---

### 6 · Guard rails — antes de conectar, não depois

Esta é a etapa que as pessoas pulam e se arrependem. Em `.claude/settings.json`,
**negue**:

```
databricks bundle destroy
databricks bundle deploy --target prod
rm -rf
git push --force
```

E um hook em `.claude/hooks/` que bloqueie `DROP`, `TRUNCATE` e `DELETE` sem
`WHERE`.

> **Hook é determinístico.** Skill e MCP são probabilísticos: dependem de o
> modelo entender. O hook não depende de nada — se ele bloqueia, bloqueia
> sempre.

Vale a pena porque isso acontece de verdade: alguém pluga o MCP num ambiente
de produção, escreve o prompt um pouco diferente, o modelo interpreta torto, e
o `DROP TABLE` vai. O guard rail existe para esse dia.

---

### 7 · Os seis prompts, na ordem

Cada um está num arquivo próprio em [`prd/`](prd). A sequência de comandos é
sempre a mesma: **prompt → deploy → run → validar**.

```console
# uma única vez, antes de tudo: o catálogo
➜  rotaperfume bash scripts/criar-catalogo.sh SEU-PERFIL

# a cada prompt
➜  rotaperfume databricks bundle validate --target dev --profile SEU-PERFIL
➜  rotaperfume databricks bundle deploy   --target dev --profile SEU-PERFIL
➜  rotaperfume databricks bundle run rotaperfume_pipeline --target dev --profile SEU-PERFIL
```

No **prompt 1** entra um passo a mais entre o deploy e o run, porque o Volume
precisa existir antes de receber arquivo:

```console
➜  rotaperfume bash scripts/subir-raw.sh SEU-PERFIL
```

O número que confirma cada passo:

| Passo | Rode | Tem que dar |
|---|---|---|
| 1 · Raw | `SELECT * FROM bronze._raw_arquivos` | 10 arquivos · 313.551 linhas |
| 2 · Bronze | `SELECT COUNT(*) FROM bronze.itens_pedido` | 197.724 |
| 3 · Silver | `SELECT COUNT(*), COUNT(DISTINCT cnpj) FROM silver.clientes` | 3.000 e 3.000 |
| 3 · Silver | `SELECT SUM(valor_liquido) FROM silver.pedidos` | **R$ 102.303.828,05** |
| 4 · Gold | `SELECT COUNT(*), SUM(receita) FROM gold.fato_vendas` | 191.080 · o mesmo valor |
| 5 · Dashboard | abrir o link do `bundle summary` | 14 widgets |
| 6 · Genie | perguntar *"Dezembro foi um mês ruim?"* | ele responde **não** |

---

### 🚑 Quando der errado

| Mensagem | O que é | Correção |
|---|---|---|
| `stored credentials from older CLI versions` | Cache antigo da CLI | `databricks auth login` |
| `Metastore storage root URL does not exist` | O bundle tentou criar o catálogo pela API | Use `scripts/criar-catalogo.sh` — no Free Edition só SQL cria catálogo |
| Os schemas viraram `dev_seunome_bronze` | `mode: development` no target | Tire o `mode` e use `presets: trigger_pause_status: PAUSED` |
| `CAST_INVALID_INPUT` e a query morre | `to_date` em ANSI mode | Sempre `try_to_date` |
| `Tree node ... does not exist` | A pasta do workspace não existe | `databricks workspace mkdirs <caminho>` |
| `databricks fs cp` reclama do caminho | Faltou o esquema `dbfs:` | O destino é `dbfs:/Volumes/...`, mesmo em Volume do UC |
| Deploy falha por falta de compute | Você respondeu `no` para serverless | Corrija o `databricks.yml` ou refaça o `bundle init` |
| Biblioteca não instala | Você está no Python 3.13 | Volte para 3.12 |
| O MCP não aparece | Falta reiniciar | Feche e abra o Claude Code |
| Cota estourou e o compute não liga | Limite do Free Edition | Espera o reset, ou use o plano B em DuckDB |

---

## 📋 Os seis prompts

Cada um está num arquivo próprio, com o prompt copiável, o que falar enquanto
o Claude Code trabalha, como validar ao vivo e uma tabela **"se der errado"**.

| # | Entrega | Arquivo |
|---|---|---|
| — | **Reset** — apaga tudo, para provar que os seis bastam | [`prompt-00-reset.md`](prd/prompt-00-reset.md) |
| 1 | **Raw** — bundle, catálogo, Volume e conferência de chegada | [`prompt-01-raw.md`](prd/prompt-01-raw.md) |
| 2 | **Bronze** — 10 tabelas Delta, sujeira preservada | [`prompt-02-bronze.md`](prd/prompt-02-bronze.md) |
| 3 | **Silver** — limpeza com contrato de qualidade | [`prompt-03-silver.md`](prd/prompt-03-silver.md) |
| 4 | **Gold** — dimensões, fato, marts e os 9 testes | [`prompt-04-gold.md`](prd/prompt-04-gold.md) |
| 5 | **Dashboard** — AI/BI versionado no bundle | [`prompt-05-dashboard.md`](prd/prompt-05-dashboard.md) |
| 6 | **Agentes de IA** — metadado, views de negócio, Genie | [`prompt-06-agentes.md`](prd/prompt-06-agentes.md) |

O contexto do projeto que o Claude Code lê antes de tudo está em
[`prd/CLAUDE.md`](prd/CLAUDE.md).

---

## 🧹 A sujeira da noite 1, e como cada uma some

Cada item foi **medido**, não estimado:

| Problema | Quantos | Como a silver resolve |
|---|---|---|
| Data em `dd/MM/yyyy` | 3.443 pedidos (12%) | `coalesce(try_to_date(c,'yyyy-MM-dd'), try_to_date(c,'dd/MM/yyyy'))` |
| CNPJ pontuado | 1.111 clientes | `regexp_replace(cnpj, '[^0-9]', '')` |
| CNPJ com espaço em volta | 223 clientes | `trim()` antes de tudo |
| CNPJ com zero à esquerda | 309 clientes | `lpad(..., 14, '0')` — e nunca converter para número |
| Mesmo CNPJ, cadastros diferentes | 40 clientes | `row_number()` por CNPJ, mantém o mais antigo |
| Devolução como quantidade negativa | 2.327 itens | coluna `devolucao` + `quantidade_abs`, **sem descartar** |
| Cancelado com valor zerado | 957 pedidos | flag `cancelado` explícita |
| SKU descontinuado em venda | 76 itens | join com produtos, coluna `sku_descontinuado` |
| Carteira ativa de vendedor desligado | 441 vínculos | coluna `orfao_vendedor_desligado`, que **expõe** em vez de consertar |

---

## 🔢 O que tem que aparecer na tela

Rodado de ponta a ponta, do catálogo vazio, com `seed 42`:

| Onde | Número |
|---|---|
| Raw no Volume | 10 arquivos · 14,7 MB · 313.551 linhas |
| Silver · clientes | 3.000 (eram 3.040) |
| **Silver · receita** | **R$ 102.303.828,05** — o mesmo da noite 1 |
| Gold · `fato_vendas` | 191.080 linhas · R$ 102.303.828,05 |
| Gold · bruto vendido | R$ 103.568.586,35 |
| Gold · margem | R$ 41,1 mi · 40,2% |
| Marca líder | Layali R$ 18,4 mi líquido · R$ 18,6 mi bruto |
| Margem por categoria | Kit Presente 33,0% · Óleo Concentrado 49,9% |
| Outubro/2025 · Janeiro/2026 | R$ 7,02 mi · R$ 2,46 mi |
| Clientes em risco | 503 · R$ 836 mil/mês parados |
| Testes | 9 de qualidade + 2 de metadado, todos passando |

**O teste que mais importa é o primeiro:** limpeza **não pode mudar o
faturamento**. Se mudou, você jogou dado fora sem querer — e três meses depois
alguém compara dois relatórios numa reunião e a discussão vira sobre qual
sistema está certo.

### 🔍 A armadilha que quase passou

A primeira versão do `fato_vendas` deixava a devolução **de fora**. Parecia
certo: "receita é o que vendeu". O resultado: a gold mostrava R$ 103,6 mi e a
silver R$ 102,3 mi. **R$ 1,26 milhão de diferença entre duas camadas do mesmo
pipeline.**

A devolução ficou **dentro** do fato, com flag e valor negativo:

```sql
SUM(receita)                                  -- R$ 102,3 mi, igual à silver
SUM(receita) FILTER (WHERE NOT devolucao)     -- R$ 103,6 mi, o bruto vendido
```

Quem quer cada número tem como pedir, e os dois reconciliam.

### 🧨 A constraint que estava errada

A regra `valor_liquido >= 0` parece óbvia, e **falhou em 135 pedidos**. A
investigação mostrou que os 135 têm item devolvido: o saldo do pedido virou
negativo, e é negócio legítimo. A regra errada era a nossa.

É exatamente para isso que a constraint serve — ela transformou uma suposição
em pergunta **antes** de a suposição virar número no dashboard.

---

## 🗂️ O projeto

```
rotaperfume/
├── databricks.yml                    o bundle, targets dev e prod
├── scripts/
│   ├── criar-catalogo.sh             o catálogo (por SQL — veja abaixo)
│   └── subir-raw.sh                  os CSVs para o Volume
├── resources/
│   ├── catalogo.yml                  schemas e volume como código
│   ├── pipeline.job.yml              o job de 12 tarefas
│   ├── dashboard.dashboard.yml       + dashboard-comercial.lvdash.json
│   └── genie.genie_space.yml         + comercial.geniespace.json
└── src/
    ├── raw/conferencia.py            os 10 arquivos chegaram?
    ├── bronze/ingestao.py            CSV → Delta, sem limpar nada
    ├── silver/01..04*.sql            a limpeza, com CONSTRAINT
    └── gold/05..10*.sql              dimensões, fato, marts, testes, views
```

### Como rodar

```bash
cd aulas/aula-02-engenharia-de-dados/rotaperfume
bash scripts/criar-catalogo.sh SEU-PERFIL
databricks bundle deploy --target dev --profile SEU-PERFIL
bash scripts/subir-raw.sh SEU-PERFIL
databricks bundle run rotaperfume_pipeline --target dev --profile SEU-PERFIL
```

### Para zerar e recomeçar

```bash
bash prd/00-reset.sh SEU-PERFIL          # simula
bash prd/00-reset.sh SEU-PERFIL --sim    # apaga de verdade
```

---

## ⚠️ Armadilhas medidas contra o workspace

Estas custaram tempo na preparação. Estão documentadas dentro do prompt onde
aparecem, com a correção em uma frase.

1. **O bundle não consegue criar catálogo no Free Edition.** Com Default
   Storage ligado, a API do Unity Catalog pede um `MANAGED LOCATION` que a
   conta gratuita não tem. Só a UI e o `CREATE CATALOG` em SQL conseguem — por
   isso existe o `scripts/criar-catalogo.sh`.

2. **`mode: development` prefixa os schemas do UC.** `bronze` viraria
   `dev_seunome_bronze` e todo o SQL da noite quebraria. O target `dev` não usa
   `mode`; o agendamento é pausado com `presets: trigger_pause_status: PAUSED`.

3. **`to_date` aborta a query em ANSI mode.** Data malformada levanta
   `CAST_INVALID_INPUT` em vez de virar `NULL`. Sempre `try_to_date`.

4. **`inferSchema` na bronze apaga evidência.** O CNPJ vira número e some com
   os 309 zeros à esquerda. A bronze lê tudo como texto, de propósito.

5. **`read_files` injeta `_rescued_data`.** Descarte com
   `SELECT * EXCEPT (_rescued_data)`. Passar `rescuedDataColumn => ''` cria uma
   coluna de nome vazio e o `CREATE TABLE` falha.

6. **`databricks fs cp` exige o esquema `dbfs:`**, mesmo para Volumes do UC.

7. **O Genie space exige listas ordenadas e ids de 32 hex** em cada pergunta e
   instrução. Gere os ids por hash do conteúdo, nunca aleatórios.

---

## 🤖 O quarto ambiente: Claude Code

Na noite 1 a pergunta foi respondida em três ambientes — Claude Web, SQL e
Genie. Os três **respondem**. O Claude Code é diferente: ele **constrói**.

| | Claude Web | SQL | Genie | **Claude Code** |
|---|---|---|---|---|
| Escala | ○ | ● | ● | ● |
| Reproduz | ○ | ● | ◐ | ● |
| Governado | ○ | ● | ● | ● |
| **Constrói** | ○ | ○ | ○ | **●** |

Três coisas ficam visíveis ao vivo, e é isso que o separa dos outros três:
**ele escreve o arquivo** (versionado no Git, não numa janela de chat que
some), **ele roda** (executa no workspace e lê o resultado de volta) e **ele
confere** (se a receita não bater, o teste quebra e ele corrige, em vez de
entregar um número errado com confiança).

> O Genie responde "qual foi a receita". O Claude Code entrega a tabela que
> passa a responder isso todo dia, sozinha.

E ele erra igual aos outros quando o dado está bagunçado. A diferença é que o
erro **aparece**: a query quebra, o teste falha, e você vê. Foi assim que este
repositório descobriu que `to_date` aborta em ANSI mode — e que a constraint
`valor_liquido >= 0` estava errada.

---

## ➡️ Amanhã

Com a `gold.fato_vendas` de pé e o Genie respondendo sobre dado limpo, as três
perguntas da diretoria deixam de ser consulta e viram modelo.
