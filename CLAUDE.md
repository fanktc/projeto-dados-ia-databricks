# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## O que é este repositório

Material e código da **Imersão Jornada de Dados** (24 a 27 de agosto de 2026): construir do zero,
ao vivo em 4 noites, a área de dados e vendas da **Rota do Perfume** — distribuidora B2B fictícia
de perfumaria árabe. Todo o conteúdo é em português e escrito para ser acompanhado ao vivo.

O repositório tem duas partes independentes, sem código compartilhado entre elas:

| Pasta | O que é |
|---|---|
| `files/` | Material da aula: PRD completo (`PRD-imersao-rota-do-perfume.md`, 875 linhas — a especificação canônica das 4 noites), gerador do dataset, slides e o zip com os CSVs |
| `sql/` | Noite 1: `n1_00_setup`, `n1_01_bronze`, `n1_02..04` (análises), `n1_99_verificacao` |
| `notebooks/` | `n1_receita.py` — receita por mês lendo o CSV local, sem Databricks |
| `scripts/` | `run_sql.py` — executa um `.sql` no warehouse, statement por statement |
| `dados/` | Dataset gerado, **não versionado**. Reproduza com `python3 files/gerar_dataset.py --saida ./dados --seed 42` |
| `perfumesarabe/` | Projeto Databricks Asset Bundle (DAB) gerado pelo template `default-python`, ainda **não customizado** para o domínio |

Cada pasta tem seu próprio arquivo de instruções, carregado quando você trabalha nela:
`files/CLAUDE.md` (regras do dataset e convenções de análise) e `perfumesarabe/CLAUDE.md`
(importa `perfumesarabe/AGENTS.md`).

## Databricks

- Trabalho relacionado a Databricks passa pelas skills: carregue `databricks-core` (skill pai)
  **antes** de qualquer ação, mais a skill do produto correspondente (`databricks-dabs`,
  `databricks-pipelines`, `databricks-jobs`, etc.).
- **Nunca escolha um profile automaticamente.** Passe `--profile <nome>` e deixe o usuário decidir.
  Profiles disponíveis em `.databrickscfg`: `DEFAULT`, `dbc-755bf06d-df36`, `jornada`, `Jornada2`,
  `grid_intelligence`, `projeto-dados-ia`.
- O ambiente-alvo é **Databricks Free Edition (serverless)**: nada que exija cluster dedicado.

### Catálogo

`rota_perfume`, schemas `bronze`/`silver`/`gold`, criado no workspace do profile
`projeto-dados-ia`. O bundle já aponta para ele (a divergência com `perfumearabe` foi corrigida).

Não existe compute clássico na Free Edition: tudo roda no SQL Warehouse serverless
`Serverless Starter Warehouse`. `python3 scripts/run_sql.py <arquivo.sql>` executa um `.sql`
statement por statement (a CLI só aceita uma por chamada, e um statement que começa com
comentário `--` seria confundido com flag se passado como argumento — por isso o runner usa stdin).
Passe `--continuar` em arquivos que contêm query que falha de propósito.

## Comandos

### Bundle (`perfumesarabe/`)

```bash
uv sync --dev                                    # instala dependências (pytest, ruff, dlt, db-connect)
uv run pytest                                    # todos os testes
uv run pytest tests/sample_taxis_test.py::test_find_all_taxis   # um teste
uv run ruff check .                              # lint (line-length 120)

databricks bundle validate --profile <perfil>
databricks bundle deploy --target dev  --profile <perfil>   # dev é o target default
databricks bundle deploy --target prod --profile <perfil>
databricks bundle run --profile <perfil>
databricks bundle run perfumesarabe_etl --refresh sample_trips_perfumesarabe --profile <perfil>  # uma transformação
```

Os testes usam **Databricks Connect** e exigem workspace acessível — `tests/conftest.py` faz
fallback para serverless se nenhum compute estiver configurado. Não existe execução local pura.

### Dataset (`files/`)

```bash
python gerar_dataset.py --saida ./dados --seed 42   # sem dependências externas
unzip dados-rota-do-perfume.zip                     # ou apenas descompacte o pronto (~14 MB)
```

## Arquitetura do bundle `perfumesarabe/`

Estado atual: **template intocado**. Todo o código de exemplo lê `samples.nyctaxi.trips` —
`src/perfumesarabe/taxis.py`, as duas transformações em `src/perfumesarabe_etl/transformations/`
e `tests/sample_taxis_test.py`. Ao começar a implementar o domínio real, esses arquivos são
para substituir, não para estender.

Três caminhos de deploy convivem, todos parametrizados pelas variáveis `catalog` e `schema`
declaradas em `databricks.yml`:

1. **Wheel** — `src/perfumesarabe/` é empacotado (`uv build --wheel`, artifact `python_artifact`)
   e o entrypoint `main` (`[project.scripts]`) recebe `--catalog` e `--schema`.
2. **Pipeline declarativo** — `src/perfumesarabe_etl/transformations/`, um dataset por arquivo,
   decorados com `@dp.table` (`from pyspark import pipelines as dp`). Serverless, `root_path`
   apontando para `src/perfumesarabe_etl`. Dependências de pipeline vão na seção `environment`
   do `.pipeline.yml`, **não** em `pyproject.toml` (são cacheadas em desenvolvimento).
3. **Job** — `resources/sample_job.job.yml` encadeia notebook → wheel + refresh do pipeline,
   com trigger diário (pausado automaticamente no target `dev`, que usa `mode: development`).

`src/perfumesarabe_etl/explorations/` é ignorado pelo `.gitignore` — notebooks ad-hoc não versionam.

## Armadilhas já verificadas contra o workspace

Estas foram testadas na Noite 1 e valem para o resto do projeto:

- **ANSI mode está ligado.** `to_date` e `date_trunc` sobre data malformada **abortam a query**
  com `CAST_INVALID_INPUT` — não retornam `NULL`. Use sempre `try_to_date`. O código da Noite 2
  no PRD (`:288-324`, `:334-360`) usa `to_date` e vai quebrar como está.
- **`read_files` injeta `_rescued_data`.** Descarte com `SELECT * EXCEPT (_rescued_data)`.
  Passar `rescuedDataColumn => ''` não desliga a coluna: cria uma com nome vazio, e o
  `CREATE TABLE` falha com `INVALID_PARAMETER_VALUE`.
- **`inferColumnTypes => false`** é o equivalente do `inferSchema=false` do PySpark. Sem ele o
  CNPJ vira número e perde os zeros à esquerda (309 registros).
- Os CSVs são **CRLF**. O leitor padrão trata bem; não use `multiLine => true`.
- `databricks fs cp` exige o esquema `dbfs:` mesmo para Volumes UC.

## Domínio: Rota do Perfume

O contrato de dados, as 10 "sujeiras propositais", o comportamento esperado dos números e as
convenções de nomenclatura estão em `files/CLAUDE.md` e no PRD. Os pontos que mudam decisões
mesmo fora da pasta `files/`:

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
