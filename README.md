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

Antes de treinar qualquer modelo, vale medir se o dado sustenta a pergunta.
Um explorer por pergunta, todos rodando local, sem Databricks:

```bash
cd notebooks
python3 n3_explorer_propensao.py   # Quem vai comprar?
python3 n3_explorer_churn.py       # Quem está sumindo?
python3 n3_explorer_previsao.py    # Quanto vamos vender?
```

| Pergunta | Resposta medida |
|---|---|
| Quem vai comprar? | **Sim.** 2.816 clientes com histórico, 93% com ritmo mensurável. Use janela de 30 dias (41% de eventos) — com 90 dias, 81% compram e não há o que aprender |
| Quem está sumindo? | **Sim, mas a definição é sua.** Não existe coluna de churn: 170 clientes (6,5%) estão atrasados em relação ao próprio ritmo. Corte relativo, não fixo |
| Quanto vamos vender? | **Sim, com ressalvas.** O mês explica 87% da variação, mas são só 2 ciclos anuais e não há tendência de crescimento para extrapolar |

## Estrutura

```
dados/         dataset gerado (não versionado — reproduza com o comando acima)
files/         PRD, gerador do dataset, slides, zip de referência
sql/           n1_00_setup · n1_01_bronze · n1_02..04 análises · n1_99 verificação
notebooks/     n1_receita.py e os explorers das 3 perguntas (n3_explorer_*)
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
