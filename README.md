# Rota do Perfume — Imersão Jornada de Dados

Área de dados e vendas de uma distribuidora B2B de perfumaria árabe, construída
do zero em 4 noites (24 a 27 de agosto de 2026). Empresa fictícia, dado gerado,
sujeira proposital.

O material da imersão está em [`files/`](files/) — o
[PRD](files/PRD-imersao-rota-do-perfume.md) é a especificação das 4 noites.

## Noite 1 — do CSV à primeira análise

Quatro comandos, do zero ao número na tela.

```bash
# 1. gerar o dataset (seed fixa: todo mundo gera exatamente o mesmo dado)
python3 files/gerar_dataset.py --saida ./dados --seed 42

# 2. criar catálogo, schemas e volume no Unity Catalog
python3 scripts/run_sql.py sql/n1_00_setup.sql

# 3. subir os CSVs para o volume
databricks fs cp --recursive --overwrite dados/erp \
  dbfs:/Volumes/rota_perfume/bronze/raw/erp --profile projeto-dados-ia
databricks fs cp --recursive --overwrite dados/crm \
  dbfs:/Volumes/rota_perfume/bronze/raw/crm --profile projeto-dados-ia

# 4. ingerir as 10 tabelas bronze
python3 scripts/run_sql.py sql/n1_01_bronze.sql
```

E as análises:

```bash
python3 scripts/run_sql.py sql/n1_02_receita_mensal.sql --continuar  # a query que quebra, e a que funciona
python3 scripts/run_sql.py sql/n1_03_top_clientes.sql
python3 scripts/run_sql.py sql/n1_04_extras.sql
python3 scripts/run_sql.py sql/n1_99_verificacao.sql                 # confere os números-âncora
```

Sem Databricks nenhum, direto do CSV (é o plano B se o workspace cair):

```bash
python3 notebooks/n1_receita.py
```

### O que deve aparecer

| Métrica | Valor |
|---|---|
| Receita, 24 meses | R$ 102.303.828,05 |
| Pedidos faturados | 27.772 |
| Ticket médio | R$ 3.683,70 |
| Melhor mês | outubro/2025 — R$ 7.015.776,84 |
| Pior mês | janeiro/2026 — R$ 2.464.039,29 |

O pico é o mês **anterior** à data comemorativa: o varejo compra antes.
Abril puxa o Dia das Mães, junho o Namorados, outubro a Black Friday.
Dezembro e janeiro são vale — o varejo já está abastecido.

Se uma query der resultado muito diferente disso, o erro está na query.
`sql/n1_99_verificacao.sql` checa isso automaticamente.

## As três perguntas da diretoria

Tudo em SQL, sobre a bronze, rodando no warehouse:

```bash
python3 scripts/run_sql.py sql/n3_01_quem_vai_comprar.sql
python3 scripts/run_sql.py sql/n3_02_quem_esta_sumindo.sql
python3 scripts/run_sql.py sql/n3_03_quanto_vamos_vender.sql
```

Nenhum modelo de machine learning. Cada cliente tem um ritmo de compra, e é
disso que saem as três respostas — com a régua testada antes de virar lista.

**Quem vai comprar?** 896 clientes entram na janela de compra nos próximos
30 dias, somando **R$ 3.515.297** esperados. A régua foi validada voltando a
31/07 e conferindo agosto: **acertou 72,7%**, contra 42,3% de quem ligasse
para a base inteira — 1,7x melhor que não ter régua nenhuma.

**Quem está sumindo?** 69 clientes (2,6%) estão atrasados frente ao próprio
ritmo e ainda dá para recuperar: **R$ 648.694 por trimestre** em risco. Outros
100 já estão parados há mais de um ano — esses são perda, não risco.

O corte fixo de "90 dias sem comprar" acusaria 401 clientes. **231 deles estão
apenas no ritmo deles** — quem compra de trimestre em trimestre não sumiu.

**Quanto vamos vender?** Outubro/2026 deve fazer **R$ 7,4 milhões** (índice
sazonal 1,68), contra R$ 4,3 mi em setembro e R$ 5,4 mi em novembro. O método
foi testado prevendo agosto sem olhar para ele: **errou 1,2%**.

A margem de ±15% não vem desse erro — vem de outubro só ter sido observado
duas vezes em toda a base.

## Estrutura

```
dados/         dataset gerado (não versionado — reproduza com o comando acima)
files/         PRD, gerador do dataset, slides, zip de referência
sql/           n1_* noite 1 (setup, bronze, análises) · n3_* as 3 perguntas
notebooks/     n1_receita.py — receita por mês sem Databricks
scripts/       run_sql.py — roda um .sql statement por statement
perfumesarabe/ bundle de deploy (DABs) — entra pra valer na noite 4
```

## Convenções

- Catálogo `rota_perfume`, schemas `bronze` / `silver` / `gold`.
- Tabelas e colunas em snake_case e português, iguais às do CSV.
- A bronze guarda o dado como veio, **com a sujeira**. Limpar é a noite 2.
- Profile Databricks: passe sempre `--profile`, nunca dependa do default.

## Por que a bronze é toda de texto

Porque o dado chega sujo, e o tipo errado apaga a evidência antes de alguém ver:

- 3.443 pedidos (12%) têm a data em `dd/mm/aaaa` em vez de ISO;
- 223 CNPJs vêm com espaço em volta, 1.111 vêm pontuados;
- 309 CNPJs começam com zero — inferir número apagaria esses zeros;
- 2.327 itens têm quantidade negativa (devolução);
- 957 pedidos cancelados têm `valor_total = 0` mas os itens seguem com valor cheio.

`sql/n1_02_receita_mensal.sql` mostra o efeito disso: a query "óbvia" não
devolve resposta errada — ela falha. É o começo da noite 2.
