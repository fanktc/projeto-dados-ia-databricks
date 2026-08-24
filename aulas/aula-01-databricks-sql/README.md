# 📚 Dia 1: Databricks & SQL | Imersão Jornada de Dados

Bem-vindo ao **primeiro dia da imersão**. Hoje você monta o ambiente, sobe o dado
para o catálogo e responde a primeira pergunta da diretoria — em quatro
ferramentas diferentes.

> 📺 **Gravação da aula:** https://youtube.com/live/plG6mF-ib_w
>
> **Domínio:** Rota do Perfume, distribuidora B2B de perfumaria árabe
> **Pergunta da noite:** *"Qual foi nossa receita e quem são os melhores clientes?"*
> **Conexão:** o que você achar de sujeira hoje é exatamente o que a **aula-02**
> vai limpar na camada silver.

---

## 🧠 Antes de tudo: por que SQL, se existe IA?

Você vai responder a mesma pergunta em três ambientes hoje — Claude Web, SQL e
Genie — e vai ver os três errarem de jeitos diferentes. O ponto da noite não é
escolher um vencedor: é entender que **nenhum deles funciona sobre dado
bagunçado**.

O quarto ambiente, o Claude Code, fica para a [noite 2](../aula-02-engenharia-de-dados).
Ele não responde pergunta — ele constrói — e só faz sentido quando já existe
pipeline para construir.

O Genie responde em português e parece mágica. Ele só acerta porque o Unity
Catalog sabe o schema, e porque quem perguntou sabia o que perguntar.

---

## 🛠️ Plataforma: Databricks Free Edition

Sem cartão, sem pegadinha. Tudo roda em **serverless**: você não cria cluster,
não configura máquina. Um SQL Warehouse liga sozinho quando você roda a
primeira query.

Crie a conta em [databricks.com/learn/free-edition](https://databricks.com/learn/free-edition).

---

## 🗄️ O dado que vamos usar

Gere na sua máquina — a seed é fixa, então seu dado é idêntico ao meu:

```bash
python3 material/gerar_dataset.py --saida ./dados --seed 42
```

```
Catálogo: lakehouse_rotaperfume
└── bronze                 (o dado como veio, sujeira inclusa)
    ├── pedidos            28.729   — a tabela fato
    ├── itens_pedido      197.724   — uma linha por produto vendido
    ├── clientes            3.040   — CNPJ, segmento, cidade
    ├── produtos              292   — categoria, marca, custo
    └── + 6 tabelas de ERP e CRM
```

### 📋 pedidos — a tabela que responde a pergunta da noite

| Coluna | O que é | Cuidado |
|---|---|---|
| `pedido_id` | ID único | |
| `cliente_id` | FK → clientes | |
| `vendedor_id` | FK → vendedores | |
| `data_pedido` | Quando aconteceu | ⚠️ **12% vêm como `dd/mm/aaaa`** |
| `canal` | Visita, WhatsApp, E-commerce… | |
| `status` | Entregue, Faturado, **Cancelado** | ⚠️ cancelado tem valor zerado |
| `valor_total` | Valor do pedido | ⚠️ é **texto** na bronze |

### 🔗 Como as tabelas se conectam

```
clientes 1──N pedidos 1──N itens_pedido N──1 produtos
clientes 1──N visitas
clientes 1──N oportunidades
pedidos  1──1 pagamentos
```

> **Por que toda coluna é texto?** Porque se o Spark adivinhasse os tipos, ele
> transformaria `15/10/2025` em nulo e apagaria os zeros à esquerda do CNPJ. A
> bronze preserva o problema para que ele possa ser resolvido — não escondido.

---

## 🎯 Roteiro de aprendizado

Os **6 exemplos** seguem uma progressão em que cada um usa o anterior:

```
  Fundamentos                    Resposta de negócio
  (01 → 02 → 03)                 (04 → 05 → 06)

  Ver, ordenar, filtrar          Receita no tempo, melhores
  e achar a sujeira              clientes, margem e marca
```

### Preparação — rode uma vez

| Arquivo | O que faz |
|---|---|
| `00-setup-catalogo.sql` | cria o catálogo, os 3 schemas e o volume |
| `01-ingestao-bronze.sql` | lê os 10 CSVs do volume e cria as tabelas |

Entre os dois, suba os CSVs:

```bash
databricks fs cp --recursive --overwrite dados/erp \
  dbfs:/Volumes/lakehouse_rotaperfume/bronze/raw/erp --profile SEU-PERFIL
databricks fs cp --recursive --overwrite dados/crm \
  dbfs:/Volumes/lakehouse_rotaperfume/bronze/raw/crm --profile SEU-PERFIL
```

### Os exemplos

| # | Arquivo | Conceito | Pergunta de negócio |
|---|---|---|---|
| 01 | `exemplo-01-primeiro-select.sql` | `SELECT`, `FROM`, `LIMIT` | O que existe no catálogo? |
| 02 | `exemplo-02-order-by-e-distinct.sql` | `ORDER BY`, `DISTINCT`, `CAST` | Qual foi o maior pedido? |
| 03 | `exemplo-03-where-e-a-sujeira.sql` | `WHERE`, `LIKE`, `FILTER` | Quais pedidos contam como receita? |
| 04 | `exemplo-04-group-by-receita-no-tempo.sql` | `GROUP BY`, `date_trunc` | **Qual foi nossa receita?** |
| 05 | `exemplo-05-join-melhores-clientes.sql` | `JOIN`, `GROUP BY` | **Quem são os melhores clientes?** |
| 06 | `exemplo-06-margem-marca-e-sazonalidade.sql` | janela, `FILTER`, margem | Onde a receita concentra? |

> As três perguntas da diretoria — quem vai comprar, quem está sumindo, quanto
> vamos vender — são a [noite 3](../aula-03-ciencia-de-dados-e-agentes). Lá elas
> já estão respondidas em SQL puro, e depois ganham modelo.

### 📓 Para dar a aula: os notebooks em branco

[`notebooks-em-branco/`](notebooks-em-branco) tem os mesmos seis exemplos, mas
**só com as perguntas** — as células de query estão vazias, para escrever ao
vivo. Cada pergunta traz a dica dos comandos e o resultado esperado, então dá
para conferir na hora se saiu certo.

```bash
DEST=/Workspace/Users/SEU-EMAIL/imersao-aula-01
databricks workspace mkdirs $DEST --profile SEU-PERFIL
for f in aulas/aula-01-databricks-sql/notebooks-em-branco/*.sql; do
  databricks workspace import "$DEST/$(basename "$f" .sql)" --file "$f" \
    --language SQL --format SOURCE --overwrite --profile SEU-PERFIL
done
```

### Como rodar os exemplos resolvidos

```bash
python3 scripts/run_sql.py aulas/aula-01-databricks-sql/exemplo-01-primeiro-select.sql
```

O `exemplo-04` tem uma query que **falha de propósito** — use `--continuar`:

```bash
python3 scripts/run_sql.py aulas/aula-01-databricks-sql/exemplo-04-group-by-receita-no-tempo.sql --continuar
```

---

## 🔢 O que deve aparecer na tela

Se um número seu divergir muito destes, o erro está na query, não no dado.
`99-verificacao.sql` confere isso automaticamente.

| Métrica | Valor |
|---|---|
| Receita, 24 meses | R$ 102.303.828,05 |
| Pedidos faturados | 27.772 |
| Ticket médio | R$ 3.683,70 |
| Melhor mês | outubro/2025 — R$ 7.015.776,84 |
| Pior mês | janeiro/2026 — R$ 2.464.039,29 |
| Marca líder | Layali — R$ 18,6 mi (Attar Real: R$ 5,2 mi) |
| Melhor margem | Óleo Concentrado 49,9% (Kit Presente: 33,0%) |

### 🔄 O insight que a turma não espera

O pico **não é dezembro**. O varejo compra *antes* da data comemorativa, então
o pico da distribuidora é o mês anterior:

```
  abril    → reposição para o Dia das Mães
  junho    → Dia dos Namorados
  outubro  → reposição para a Black Friday
  dez/jan  → vale: o varejo já está abastecido
```

---

## 🧰 Os outros ambientes da noite

| Arquivo | Para que serve |
|---|---|
| `roteiro-genie-e-dashboard.md` | O bloco sem código: perguntas do Genie e o dashboard, com o que esperar |
| `dashboard-bronze.lvdash.json` | O AI/BI dashboard da noite, sobre a **bronze** — 13 widgets |
| `receita-sem-databricks.py` | Receita por mês lendo o CSV local — o plano B se o workspace cair |
| `aula-01-imersao-agosto.pptx` | Os slides da noite |

### 📊 O dashboard

Já está publicado no workspace. Para recriar:

```bash
databricks lakeview create \
  --display-name "Rota do Perfume · Noite 1" \
  --warehouse-id SEU-WAREHOUSE \
  --dataset-catalog lakehouse_rotaperfume --dataset-schema bronze \
  --serialized-dashboard "$(cat aulas/aula-01-databricks-sql/dashboard-bronze.lvdash.json)" \
  --json '{"parent_path": "/Workspace/Users/SEU-EMAIL/dashboards"}' --profile SEU-PERFIL
```

Três coisas que valem mostrar ao vivo: ele é **um JSON no Git** (não algo que
alguém montou clicando), **clicar numa marca filtra tudo** (os widgets
compartilham o dataset), e as **métricas são declaradas uma vez** com
`MEASURE()`, então nenhuma tela mostra número diferente.

> Ele lê a **bronze**, então cada dataset carrega `CAST` e `try_to_date`. Na
> noite 2 o mesmo dashboard é refeito sobre a gold, com metade do SQL.

```bash
python3 aulas/aula-01-databricks-sql/receita-sem-databricks.py
```

---

## ➡️ Amanhã

A query do `exemplo-04` **quebra** por causa das datas em dois formatos. O
`try_to_date` que resolve isso é um rascunho da camada silver.

Amanhã a gente faz isso direito, para as 10 tabelas, com pipeline agendado e
teste que quebra antes do dashboard: [aula-02](../aula-02-engenharia-de-dados).
