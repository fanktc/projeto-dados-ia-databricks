# PRD — Imersão Dados + IA · Rota do Perfume

**Jornada de Dados · 24 a 27 de agosto de 2026 · 19h30 · 1h30 por noite**

Documento de produto do projeto técnico construído ao vivo durante a imersão.
Cobre escopo, dataset, arquitetura, o que é entregue em cada noite e o código
de referência com tempo estimado por bloco.

---

## 1. Visão do produto

### O problema
Analista de dados entrega relatório. Empresa quer decisão. Entre uma coisa e a
outra existe uma área de dados inteira que quase ninguém sabe montar.

### O que construímos
Uma área de dados e vendas completa para a **Rota do Perfume**,
empresa fictícia B2B de perfumaria árabe. Do dado bruto de ERP e CRM até um
agente de IA que diz ao vendedor para quem ligar hoje.

### Restrição central
**Cada noite tem 1h30 de aula.** Não 2h. Isso governa todas as decisões de
escopo deste documento: se um bloco não cabe em 90 minutos com margem, ele é
cortado ou vai para o material de apoio.

### Público
Profissionais que já trabalham com dados. A base captada tem 42% com 1 ano ou
mais de área e 38% iniciantes — o conteúdo é calibrado para o primeiro grupo,
com material de fundamentos indicado para o segundo.

---

## 2. Orçamento de tempo

Regra de ouro: **90 minutos são 75 minutos úteis.** Sempre há atraso de início,
pergunta no chat e aluno travado no setup.

| Bloco | Duração | Observação |
|---|---|---|
| Abertura e contrato | 8 min | O que a noite entrega |
| Contexto | 12 min | Por que isso importa |
| Mão na massa | 55 min | O bloco principal |
| Entrega e gancho | 10 min | Recap e o problema de amanhã |
| Margem | 5 min | Não planejar em cima |

**Se atrasar, corta do contexto — nunca da entrega.** O aluno perdoa teoria
curta; não perdoa aula que termina sem nada funcionando.

---

## 3. Dataset

Gerado por `gerar_dataset.py --saida ./dados --seed 42`. Seed fixa: todos os
alunos chegam exatamente no mesmo resultado. Período: set/2024 a ago/2026.
14 MB descompactado — dimensionado para o Databricks Free Edition.

### ERP — o que foi vendido

| Tabela | Linhas | Chave |
|---|---|---|
| `produtos` | 292 | `sku` |
| `pedidos` | 28.729 | `pedido_id` |
| `itens_pedido` | 197.724 | `item_id` |
| `pagamentos` | 27.772 | `pagamento_id` |
| `estoque` | 8.400 | `data_snapshot` + `sku` |

### CRM — para quem vendemos

| Tabela | Linhas | Chave |
|---|---|---|
| `clientes` | 3.040 | `cliente_id` |
| `vendedores` | 42 | `vendedor_id` |
| `carteira` | 3.637 | `carteira_id` |
| `oportunidades` | 5.979 | `oportunidade_id` |
| `visitas` | 38.112 | `visita_id` |

### Amostra real — repare na sujeira

```
cliente_id  cnpj                  razao_social                 segmento
1           26.773.602/6064-74    Perfumaria Aurora EIRELI     Perfumaria
2           05009788208121        Drogaria Bella Vita S/A      Farmácia
3           99854353462475        Boutique Essenza ME          Loja de shopping
```

O cliente 1 tem CNPJ pontuado, os outros dois não. Esse é o tipo de coisa que
quebra um `JOIN` silenciosamente.

### As 10 sujeiras propositais

| # | Sujeira | Onde aparece |
|---|---|---|
| 1 | CNPJ em 3 formatos | `clientes.cnpj` |
| 2 | Razão social em caixa alta ou sem acento | `clientes.razao_social` |
| 3 | Data em ISO e `dd/mm/aaaa` | `clientes.data_cadastro` |
| 4 | ~40 clientes duplicados | `clientes` |
| 5 | SKU descontinuado em venda | `itens_pedido` × `produtos.ativo` |
| 6 | Devolução como quantidade negativa | `itens_pedido.quantidade` |
| 7 | Cancelado com valor zerado | `pedidos.valor_total` |
| 8 | ~12% das datas em formato BR | `pedidos.data_pedido` |
| 9 | Vendedor desligado com carteira ativa | `carteira` × `vendedores` |
| 10 | Ruptura de estoque (~11%) | `estoque.saldo = 0` |

### Comportamento esperado (serve como teste)

- Receita 24 meses: R$ 102 mi · ticket médio por pedido: R$ 3.684
- Outubro/2025: R$ 7,0 mi · Janeiro/2026: R$ 2,5 mi
- Quatro picos: abril, junho, outubro. Dezembro e janeiro são vale
- Lançamentos: 47 SKUs = R$ 25,5 mi (25% da receita com 16% dos produtos)
- Marca líder Layali: R$ 18,6 mi · última Attar Real: R$ 5,2 mi
- Margem: Óleo Concentrado 49,9% · Kit Presente 33,0%
- ~11% dos clientes entram em churn

Se uma query der resultado muito diferente disso, o erro está na query.

---

## 4. Arquitetura

```
Camada       Schema     O que tem                        Noite
─────────────────────────────────────────────────────────────
Fontes       —          CSV de ERP e CRM                  —
Bronze       bronze     Ingestão crua, sujeira inclusa     2
Silver       silver     Limpo, deduplicado, tipado         2
Gold         gold       Fatos e dimensões para consumo     2
Features     gold       Tabela de features por cliente     3
Score        gold       Propensão gravada e versionada     3
Agente       —          Lê o score, decide e age           3
Deploy       —          Agendado, monitorado, no ar        4
```

**Catálogo:** `rota_perfume` · **Schemas:** `bronze`, `silver`, `gold`

---

## 5. Noite 1 · Segunda 24/08 — Objetivo e análise

**Promessa:** entender como a empresa vende, montar o ambiente e responder a
primeira pergunta em quatro ferramentas diferentes.

| Bloco | Min | Conteúdo |
|---|---|---|
| Abertura e contrato | 8 | As 4 noites, o que hoje entrega |
| Como a área comercial vende | 12 | Funil, atores, as 3 perguntas, onde trava |
| ERP, CRM e os outros sistemas | 10 | De onde vem o dado |
| Setup do Databricks | 15 | Conta, catálogo, schema, upload |
| **A mesma pergunta em 4 ambientes** | **35** | Claude Web, SQL, Genie, Claude Code |
| Recap e gancho | 10 | O que temos, o que falta |

### A pergunta da noite
> "Qual foi nossa receita e quem são os melhores clientes?"

### Bloco de 35 minutos — 4 ambientes

**1. Claude Web · 8 min**
Sobe `pedidos.csv`, pergunta em português, mostra a resposta.
Aponta o limite ao vivo: cabe pouco dado, não se repete, não é governado.

**2. SQL no Databricks · 12 min**

```sql
-- Receita por mês. Repare no filtro de cancelado:
-- pedido cancelado tem valor_total = 0 e não deve entrar na conta.
SELECT
    date_trunc('month', data_pedido) AS mes,
    COUNT(*)                          AS pedidos,
    ROUND(SUM(valor_total), 2)        AS receita
FROM rota_perfume.bronze.pedidos
WHERE status <> 'Cancelado'
GROUP BY 1
ORDER BY 1;
```

```sql
-- Top 10 clientes por receita
SELECT
    c.razao_social,
    c.segmento,
    COUNT(DISTINCT p.pedido_id)       AS pedidos,
    ROUND(SUM(p.valor_total), 2)      AS receita
FROM rota_perfume.bronze.pedidos p
JOIN rota_perfume.bronze.clientes c
  ON c.cliente_id = p.cliente_id
WHERE p.status <> 'Cancelado'
GROUP BY 1, 2
ORDER BY receita DESC
LIMIT 10;
```

> **Momento de aula:** rode a query de receita e mostre o pico de outubro e o
> vale de dezembro. A turma vai estranhar: "não era pra vender mais no Natal?"
> Aí você explica o insight do setor — a distribuidora vende ANTES da data,
> porque o varejo precisa estar abastecido. O pico dela é o mês anterior.
> Você acabou de provar que entender o negócio vem antes de escrever query.

**3. Genie · 8 min**
Mesma pergunta em português, sobre o dado governado.
Funciona — e você mostra por quê: o Unity Catalog sabe o schema e as relações.
Depois pergunte algo que dependa do dado limpo e mostre o erro.

**4. Claude Code · 7 min**

```bash
claude
```
```
> Analise o CSV em dados/erp/pedidos.csv e me diga qual foi a receita
> por mês, ignorando pedidos cancelados. Salve o resultado em
> notebooks/n1_receita.py e gere um gráfico.
```

Mostre que ele **escreve o código e roda**, em vez de só responder.

### Entregável da noite 1
Ambiente configurado, dado no catálogo, primeira análise feita nos 4 ambientes.

### Fecho
> "O Genie foi o mais confortável, né? Mas ele só acertou porque o dado tava
> razoável e eu sabia o que perguntar. Amanhã a gente arruma esse dado de
> verdade. Engenharia de dados não é o que a IA substitui — é o que faz a IA
> funcionar."

---

## 6. Noite 2 · Terça 25/08 — Engenharia de dados

**Promessa:** o projeto passa a rodar sozinho.

| Bloco | Min | Conteúdo |
|---|---|---|
| Abertura: o problema de ontem | 8 | Tudo na mão quebra se o dado mudar |
| Medallion e Delta | 12 | Bronze, silver, gold e por quê |
| **Bronze → Silver: a limpeza** | **30** | As 10 sujeiras, uma a uma |
| **Gold: o modelo de consumo** | **15** | Fatos e dimensões |
| Pipeline e testes | 15 | Agendamento, incremental, qualidade |
| Entrega e gancho | 10 | Rodar do zero ao vivo |

### Bronze — ingestão crua

```python
# notebooks/n2_bronze.py
# A bronze preserva o dado como veio. Nada de limpeza aqui:
# se der problema depois, a gente precisa poder voltar na origem.

from pyspark.sql import functions as F

CAMINHO = "/Volumes/rota_perfume/bronze/raw"

def ingerir(nome: str, subpasta: str) -> None:
    """Lê o CSV como texto e grava em Delta, sem transformar nada."""
    df = (
        spark.read
        .option("header", "true")
        .option("inferSchema", "false")   # tudo string: preserva o original
        .csv(f"{CAMINHO}/{subpasta}/{nome}.csv")
        .withColumn("_ingerido_em", F.current_timestamp())
        .withColumn("_arquivo_origem", F.input_file_name())
    )
    (df.write
       .format("delta")
       .mode("overwrite")
       .saveAsTable(f"rota_perfume.bronze.{nome}"))
    print(f"bronze.{nome}: {df.count():,} linhas")

for t in ["produtos", "pedidos", "itens_pedido", "pagamentos", "estoque"]:
    ingerir(t, "erp")

for t in ["clientes", "vendedores", "carteira", "oportunidades", "visitas"]:
    ingerir(t, "crm")
```

> **Momento de aula:** explique `inferSchema=false`. Se o Spark inferir o tipo,
> ele já vai errar nas datas em dois formatos — e você perde a evidência da
> sujeira antes de mostrar para a turma.

### Silver — a limpeza (o coração da noite)

```python
# notebooks/n2_silver_clientes.py
# Aqui resolvemos 4 das 10 sujeiras de uma vez:
# CNPJ em 3 formatos, razão social inconsistente, data em 2 formatos
# e clientes duplicados.

from pyspark.sql import functions as F, Window

bronze = spark.table("rota_perfume.bronze.clientes")

limpo = (
    bronze
    # 1. CNPJ: tira tudo que não é dígito e completa com zero à esquerda
    .withColumn("cnpj", F.lpad(F.regexp_replace(F.col("cnpj"), r"[^0-9]", ""), 14, "0"))
    # 2. Razão social: tira espaço duplo e padroniza caixa
    .withColumn("razao_social", F.initcap(F.trim(F.regexp_replace("razao_social", r"\s+", " "))))
    # 3. Data em dois formatos: tenta ISO, cai para dd/MM/yyyy
    .withColumn(
        "data_cadastro",
        F.coalesce(
            F.to_date("data_cadastro", "yyyy-MM-dd"),
            F.to_date("data_cadastro", "dd/MM/yyyy"),
        ),
    )
    .withColumn("ativo", F.col("ativo") == F.lit("S"))
    .withColumn("cliente_id", F.col("cliente_id").cast("int"))
)

# 4. Deduplicação: mesmo CNPJ = mesmo cliente.
#    Mantemos o registro mais antigo, que é o cadastro original.
janela = Window.partitionBy("cnpj").orderBy(F.col("data_cadastro").asc_nulls_last())

dedup = (
    limpo
    .withColumn("_rn", F.row_number().over(janela))
    .withColumn("_cnpj_repetido", F.count("*").over(Window.partitionBy("cnpj")) > 1)
    .filter(F.col("_rn") == 1)
    .drop("_rn")
)

print(f"bronze: {bronze.count():,}  →  silver: {dedup.count():,}")

(dedup.write.format("delta").mode("overwrite")
      .option("overwriteSchema", "true")
      .saveAsTable("rota_perfume.silver.clientes"))
```

```python
# notebooks/n2_silver_pedidos.py
# Aqui: data em 2 formatos, cancelado com valor zerado
# e o vínculo com o vendedor vigente na data do pedido.

from pyspark.sql import functions as F

pedidos = spark.table("rota_perfume.bronze.pedidos")

limpo = (
    pedidos
    .withColumn(
        "data_pedido",
        F.coalesce(
            F.to_date("data_pedido", "yyyy-MM-dd"),
            F.to_date("data_pedido", "dd/MM/yyyy"),
        ),
    )
    .withColumn("valor_total", F.col("valor_total").cast("decimal(12,2)"))
    .withColumn("cliente_id", F.col("cliente_id").cast("int"))
    .withColumn("vendedor_id", F.col("vendedor_id").cast("int"))
    # flag explícita: melhor que confiar no valor zerado
    .withColumn("cancelado", F.col("status") == F.lit("Cancelado"))
    # valor válido para análise: zero se cancelado
    .withColumn(
        "valor_liquido",
        F.when(F.col("cancelado"), F.lit(0)).otherwise(F.col("valor_total")),
    )
)

(limpo.write.format("delta").mode("overwrite")
      .option("overwriteSchema", "true")
      .partitionBy("cancelado")
      .saveAsTable("rota_perfume.silver.pedidos"))
```

```python
# notebooks/n2_silver_itens.py
# A devolução vem como quantidade negativa. Não é erro:
# é informação. Separamos em coluna própria em vez de jogar fora.

from pyspark.sql import functions as F

itens = spark.table("rota_perfume.bronze.itens_pedido")
produtos = spark.table("rota_perfume.bronze.produtos").select(
    "sku", F.col("ativo").alias("sku_ativo")
)

limpo = (
    itens
    .withColumn("quantidade", F.col("quantidade").cast("int"))
    .withColumn("preco_praticado", F.col("preco_praticado").cast("decimal(10,2)"))
    .withColumn("valor_bruto", F.col("valor_bruto").cast("decimal(12,2)"))
    .withColumn("devolucao", F.col("quantidade") < 0)
    .withColumn("quantidade_abs", F.abs("quantidade"))
    .join(produtos, "sku", "left")
    # sinaliza venda de produto descontinuado — não remove, sinaliza
    .withColumn("sku_descontinuado", F.col("sku_ativo") == F.lit("N"))
    .drop("sku_ativo")
)

(limpo.write.format("delta").mode("overwrite")
      .option("overwriteSchema", "true")
      .saveAsTable("rota_perfume.silver.itens_pedido"))
```

> **Momento de aula:** ao tratar a devolução, pare e explique a decisão.
> Jogar fora a linha esconde receita negativa e infla o faturamento. Manter sem
> flag polui toda soma. A resposta certa é sinalizar e deixar a análise decidir.

### Gold — modelo de consumo

```python
# notebooks/n2_gold_fato_vendas.py
# Uma linha por item vendido, já com tudo que a análise precisa.
# É essa tabela que o dashboard e o Genie vão consultar.

from pyspark.sql import functions as F

pedidos  = spark.table("rota_perfume.silver.pedidos").filter(~F.col("cancelado"))
itens    = spark.table("rota_perfume.silver.itens_pedido").filter(~F.col("devolucao"))
produtos = spark.table("rota_perfume.silver.produtos")
clientes = spark.table("rota_perfume.silver.clientes")

fato = (
    itens.alias("i")
    .join(pedidos.alias("p"),  "pedido_id")
    .join(produtos.alias("pr"), "sku")
    .join(clientes.alias("c"),  "cliente_id")
    .select(
        F.col("p.pedido_id"),
        F.col("p.data_pedido"),
        F.year("p.data_pedido").alias("ano"),
        F.month("p.data_pedido").alias("mes"),
        F.col("p.canal"),
        F.col("c.cliente_id"), F.col("c.razao_social"), F.col("c.segmento"), F.col("c.cidade"),
        F.col("p.vendedor_id"),
        F.col("pr.sku"), F.col("pr.categoria"), F.col("pr.marca"),
        F.col("i.quantidade"),
        F.col("i.preco_praticado"),
        F.col("i.valor_bruto").alias("receita"),
        (F.col("i.quantidade") * F.col("pr.custo_unitario")).alias("custo"),
        (F.col("i.valor_bruto") - F.col("i.quantidade") * F.col("pr.custo_unitario")).alias("margem"),
    )
)

(fato.write.format("delta").mode("overwrite")
     .option("overwriteSchema", "true")
     .partitionBy("ano", "mes")
     .saveAsTable("rota_perfume.gold.fato_vendas"))
```

### Testes de qualidade

```python
# notebooks/n2_testes.py
# Teste que quebra o pipeline antes de quebrar o dashboard.
# Roda depois de cada carga.

from pyspark.sql import functions as F

def checar(nome: str, condicao: bool, detalhe: str = "") -> None:
    if condicao:
        print(f"  OK    {nome}")
    else:
        raise AssertionError(f"FALHOU: {nome}  {detalhe}")

clientes = spark.table("rota_perfume.silver.clientes")
pedidos  = spark.table("rota_perfume.silver.pedidos")
fato     = spark.table("rota_perfume.gold.fato_vendas")

print("Rodando testes de qualidade...")

# 1. CNPJ único depois da deduplicação
dups = clientes.groupBy("cnpj").count().filter("count > 1").count()
checar("CNPJ único na silver", dups == 0, f"{dups} duplicados")

# 2. Nenhuma data nula (todo formato foi tratado)
nulas = pedidos.filter(F.col("data_pedido").isNull()).count()
checar("Datas convertidas", nulas == 0, f"{nulas} nulas")

# 3. Nenhuma receita negativa na gold (devolução já foi separada)
neg = fato.filter(F.col("receita") < 0).count()
checar("Sem receita negativa na gold", neg == 0, f"{neg} linhas")

# 4. Volume dentro do esperado — pega queda silenciosa de ingestão
n = fato.count()
checar("Volume da fato_vendas", 150_000 < n < 260_000, f"{n:,} linhas")

# 5. Todo pedido da fato existe na silver
orfaos = (fato.select("pedido_id").distinct()
              .join(pedidos.select("pedido_id"), "pedido_id", "left_anti").count())
checar("Sem pedido órfão", orfaos == 0, f"{orfaos} órfãos")

print("Todos os testes passaram.")
```

### Entregável da noite 2
Bronze, silver e gold no catálogo, pipeline agendado e testes rodando.

---

## 7. Noite 3 · Quarta 26/08 — Ciência de dados e agentes

**Promessa:** o dado vira ação. **É a noite de abertura de carrinho.**

| Bloco | Min | Conteúdo |
|---|---|---|
| Abertura | 6 | O que temos e o que falta |
| Feature engineering | 18 | RFM e as features que valem dinheiro |
| Modelo de propensão | 16 | Treino, avaliação, score gravado |
| **O agente** | **22** | Ferramentas, decisão, ação |
| Entrega | 8 | Rodar de ponta a ponta |
| **Abertura de carrinho** | **20** | Depois da entrega, nunca antes |

> **Regra inegociável:** o carrinho abre **depois** da entrega técnica.
> 380 dos 544 leads faixa A declararam que investem quando se sentem seguros.
> A prova é o argumento de venda.

### Features

```python
# notebooks/n3_features.py
# A parte que mais vale dinheiro no projeto.
# RFM clássico + sinais de comportamento comercial.

from pyspark.sql import functions as F, Window
from datetime import date

REFERENCIA = date(2026, 8, 31)   # "hoje" do dataset

fato   = spark.table("rota_perfume.gold.fato_vendas")
oport  = spark.table("rota_perfume.silver.oportunidades")
visita = spark.table("rota_perfume.silver.visitas")

# --- RFM ---
rfm = (
    fato.groupBy("cliente_id", "segmento", "cidade")
    .agg(
        F.datediff(F.lit(REFERENCIA), F.max("data_pedido")).alias("recencia_dias"),
        F.countDistinct("pedido_id").alias("frequencia_pedidos"),
        F.sum("receita").alias("valor_total"),
        F.avg("receita").alias("ticket_medio_item"),
        F.sum("margem").alias("margem_total"),
        F.countDistinct("sku").alias("skus_distintos"),
        F.countDistinct("categoria").alias("categorias_distintas"),
        F.min("data_pedido").alias("primeira_compra"),
    )
    .withColumn("meses_de_casa",
                F.months_between(F.lit(REFERENCIA), F.col("primeira_compra")))
    .withColumn("pedidos_por_mes",
                F.col("frequencia_pedidos") / F.greatest(F.col("meses_de_casa"), F.lit(1)))
)

# --- intervalo médio entre pedidos: sinal forte de churn ---
w = Window.partitionBy("cliente_id").orderBy("data_pedido")
intervalos = (
    fato.select("cliente_id", "data_pedido").distinct()
    .withColumn("anterior", F.lag("data_pedido").over(w))
    .withColumn("intervalo", F.datediff("data_pedido", "anterior"))
    .groupBy("cliente_id")
    .agg(F.avg("intervalo").alias("intervalo_medio_dias"),
         F.stddev("intervalo").alias("intervalo_desvio"))
)

# --- sinais de CRM ---
crm = (
    oport.groupBy("cliente_id")
    .agg(F.count("*").alias("oportunidades"),
         F.sum(F.when(F.col("etapa") == "Fechado ganho", 1).otherwise(0)).alias("oport_ganhas"))
)

vis = (
    visita.groupBy("cliente_id")
    .agg(F.count("*").alias("visitas"),
         F.sum(F.when(F.col("resultado") == "Pedido realizado", 1).otherwise(0)).alias("visitas_com_pedido"))
    .withColumn("taxa_conversao_visita",
                F.col("visitas_com_pedido") / F.greatest(F.col("visitas"), F.lit(1)))
)

features = (
    rfm.join(intervalos, "cliente_id", "left")
       .join(crm, "cliente_id", "left")
       .join(vis, "cliente_id", "left")
       .fillna(0)
       # atraso relativo: comprou há quanto tempo vs. o normal dele
       .withColumn("atraso_relativo",
                   F.col("recencia_dias") / F.greatest(F.col("intervalo_medio_dias"), F.lit(1)))
)

(features.write.format("delta").mode("overwrite")
        .option("overwriteSchema", "true")
        .saveAsTable("rota_perfume.gold.features_cliente"))
```

> **Momento de aula:** `atraso_relativo` é a feature mais importante do modelo
> e não vem de biblioteca nenhuma. Um cliente que compra a cada 7 dias e sumiu
> há 20 é urgente. Um que compra a cada 90 e sumiu há 20 está normal.
> Isso é conhecimento de negócio virando coluna.

### Modelo de propensão

```python
# notebooks/n3_modelo.py
# Objetivo: quem tem mais chance de comprar nos próximos 30 dias.
#
# CUIDADO COM VAZAMENTO DE DADO: o rótulo olha os últimos 30 dias,
# então as features precisam ser calculadas ANTES dessa janela.

import pandas as pd
from datetime import date, timedelta
from sklearn.ensemble import GradientBoostingClassifier
from sklearn.model_selection import train_test_split
from sklearn.metrics import roc_auc_score, classification_report

CORTE = date(2026, 8, 1)   # features até aqui, rótulo depois daqui

fato = spark.table("rota_perfume.gold.fato_vendas")

# rótulo: comprou entre 01/08 e 31/08?
rotulo = (
    fato.filter(f"data_pedido >= '{CORTE}'")
        .select("cliente_id").distinct()
        .withColumn("comprou_30d", F.lit(1))
)

features = (
    spark.table("rota_perfume.gold.features_cliente")
         .join(rotulo, "cliente_id", "left")
         .fillna({"comprou_30d": 0})
)

pdf = features.toPandas()

COLS = ["recencia_dias", "frequencia_pedidos", "valor_total", "ticket_medio_item",
        "skus_distintos", "categorias_distintas", "pedidos_por_mes",
        "intervalo_medio_dias", "atraso_relativo", "taxa_conversao_visita",
        "oportunidades", "oport_ganhas"]

X = pdf[COLS].fillna(0)
y = pdf["comprou_30d"]

X_tr, X_te, y_tr, y_te = train_test_split(X, y, test_size=0.25,
                                          stratify=y, random_state=42)

modelo = GradientBoostingClassifier(n_estimators=200, max_depth=4, random_state=42)
modelo.fit(X_tr, y_tr)

proba = modelo.predict_proba(X_te)[:, 1]
print(f"AUC: {roc_auc_score(y_te, proba):.3f}")
print(classification_report(y_te, modelo.predict(X_te)))

# importância — mostre isso ao vivo, é o slide mais convincente da noite
imp = pd.DataFrame({"feature": COLS, "peso": modelo.feature_importances_})
print(imp.sort_values("peso", ascending=False).to_string(index=False))

# score para toda a base, gravado como tabela versionada
pdf["score_propensao"] = modelo.predict_proba(X[COLS].fillna(0))[:, 1]
pdf["faixa"] = pd.cut(pdf["score_propensao"], [0, .3, .6, .8, 1.0],
                      labels=["Fria", "Morna", "Quente", "Muito quente"])

(spark.createDataFrame(pdf[["cliente_id", "score_propensao", "faixa"]])
      .withColumn("calculado_em", F.current_timestamp())
      .write.format("delta").mode("overwrite")
      .option("overwriteSchema", "true")
      .saveAsTable("rota_perfume.gold.score_propensao"))
```

### O agente

```python
# notebooks/n3_agente.py
# O agente não inventa resposta: ele lê as tabelas que construímos
# nas noites anteriores e decide o que o vendedor faz hoje.

from pyspark.sql import functions as F

# ---------- ferramentas ----------

def priorizar_carteira(vendedor_id: int, limite: int = 10):
    """Quem esse vendedor deve procurar hoje, e por quê."""
    score    = spark.table("rota_perfume.gold.score_propensao")
    features = spark.table("rota_perfume.gold.features_cliente")
    carteira = spark.table("rota_perfume.silver.carteira").filter(
        (F.col("vendedor_id") == vendedor_id) & F.col("data_fim").isNull()
    )
    return (
        carteira.join(score, "cliente_id")
                .join(features, "cliente_id")
                .withColumn(
                    "motivo",
                    F.when(F.col("atraso_relativo") > 2, "Atrasado — risco de perda")
                     .when(F.col("faixa") == "Muito quente", "Alta chance de comprar agora")
                     .when(F.col("valor_total") > 50000, "Cliente grande, manter próximo")
                     .otherwise("Rotina de carteira"),
                )
                .orderBy(F.desc("score_propensao"))
                .limit(limite)
                .select("cliente_id", "razao_social", "score_propensao",
                        "faixa", "recencia_dias", "motivo")
    )

def checar_disponibilidade(sku: str):
    """O produto que vou oferecer está disponível?"""
    return (
        spark.table("rota_perfume.silver.estoque")
             .filter(F.col("sku") == sku)
             .orderBy(F.desc("data_snapshot"))
             .limit(1)
             .select("sku", "saldo", "ruptura")
    )

def sugerir_produtos(cliente_id: int, limite: int = 3):
    """O que ele costuma comprar e não comprou nos últimos 60 dias."""
    fato = spark.table("rota_perfume.gold.fato_vendas")
    historico = (fato.filter(F.col("cliente_id") == cliente_id)
                     .groupBy("sku", "marca", "categoria")
                     .agg(F.sum("quantidade").alias("qtd_historica"),
                          F.max("data_pedido").alias("ultima_compra")))
    return (historico
            .filter(F.datediff(F.current_date(), F.col("ultima_compra")) > 60)
            .orderBy(F.desc("qtd_historica"))
            .limit(limite))

# ---------- o agente ----------

FERRAMENTAS = {
    "priorizar_carteira": priorizar_carteira,
    "checar_disponibilidade": checar_disponibilidade,
    "sugerir_produtos": sugerir_produtos,
}

INSTRUCAO = """
Você é o assistente comercial da Rota do Perfume.
Seu trabalho é dizer ao vendedor quem procurar hoje e o que oferecer.

Regras:
- Use SEMPRE as ferramentas. Nunca invente número de cliente, score ou saldo.
- Antes de sugerir um produto, cheque a disponibilidade em estoque.
- Explique o motivo em uma frase, na linguagem do vendedor.
- Se não houver dado suficiente, diga isso em vez de estimar.
"""
```

> **Momento de aula:** rode o agente e mostre a lista saindo. Depois abra a
> tabela `score_propensao` e mostre que o número é o mesmo. É isso que separa
> agente de chatbot: ele está lendo o que a gente construiu.

### Entregável da noite 3
Features, modelo com AUC medido, score versionado e agente respondendo.

---

## 8. Noite 4 · Quinta 27/08 — Deploy e próximos passos

**Promessa:** colocar de pé e conseguir defender internamente.

| Bloco | Min | Conteúdo |
|---|---|---|
| Abertura | 6 | O que já existe |
| Deploy: do notebook ao job | 20 | Job, agendamento, dependências |
| Monitoramento e custo | 18 | Saber que quebrou, não estourar orçamento |
| **Como defender internamente** | **20** | Apresentar para o gestor |
| Portfólio e próximos passos | 14 | GitHub, README, o que estudar |
| Fechamento | 12 | Última chamada, carrinho até sexta |

### Job de produção

```python
# jobs/pipeline_diario.py
# Ordem importa: bronze → silver → gold → features → score.
# Se um passo falhar, o pipeline para e avisa.

import sys
from datetime import datetime

PASSOS = [
    ("bronze",    "notebooks/n2_bronze.py"),
    ("silver",    "notebooks/n2_silver_clientes.py"),
    ("silver",    "notebooks/n2_silver_pedidos.py"),
    ("silver",    "notebooks/n2_silver_itens.py"),
    ("gold",      "notebooks/n2_gold_fato_vendas.py"),
    ("testes",    "notebooks/n2_testes.py"),
    ("features",  "notebooks/n3_features.py"),
    ("score",     "notebooks/n3_modelo.py"),
]

def executar():
    inicio = datetime.now()
    for camada, caminho in PASSOS:
        t0 = datetime.now()
        print(f"[{camada}] rodando {caminho}...")
        try:
            dbutils.notebook.run(caminho, timeout_seconds=1800)
        except Exception as e:
            print(f"[{camada}] FALHOU em {caminho}: {e}")
            # falha explícita: melhor pipeline parado que dashboard errado
            sys.exit(1)
        print(f"[{camada}] ok em {(datetime.now()-t0).seconds}s")
    print(f"Pipeline completo em {(datetime.now()-inicio).seconds}s")

executar()
```

### Monitoramento

```python
# notebooks/n4_monitor.py
# Três perguntas que todo pipeline precisa responder sozinho:
# rodou? o volume tá normal? o dado tá fresco?

from pyspark.sql import functions as F
from datetime import datetime

def registrar_metricas():
    fato  = spark.table("rota_perfume.gold.fato_vendas")
    score = spark.table("rota_perfume.gold.score_propensao")

    metricas = [{
        "executado_em":     datetime.now(),
        "linhas_fato":      fato.count(),
        "clientes_scorados": score.count(),
        "data_mais_recente": fato.agg(F.max("data_pedido")).collect()[0][0],
        "receita_30d": float(
            fato.filter(F.col("data_pedido") >= F.date_sub(F.current_date(), 30))
                .agg(F.sum("receita")).collect()[0][0] or 0
        ),
    }]

    (spark.createDataFrame(metricas)
          .write.format("delta").mode("append")
          .saveAsTable("rota_perfume.gold.monitor_execucao"))

    # alerta simples: variação brusca de volume indica problema
    hist = spark.table("rota_perfume.gold.monitor_execucao").orderBy(F.desc("executado_em")).limit(7)
    media = hist.agg(F.avg("linhas_fato")).collect()[0][0]
    atual = metricas[0]["linhas_fato"]
    if media and abs(atual - media) / media > 0.20:
        print(f"ALERTA: volume variou mais de 20% ({atual:,} vs média {media:,.0f})")

registrar_metricas()
```

### Como defender internamente

Roteiro de 1 slide que o aluno leva pronto:

| Item | O que dizer |
|---|---|
| Problema | "Não sabemos quem vai comprar. O vendedor liga por intuição." |
| Solução | "Um score diário que prioriza a carteira de cada vendedor." |
| Como funciona | Mostrar o diagrama das 4 camadas |
| Prova | "Rodei com o dado dos últimos 24 meses. AUC de X." |
| Custo | "Roda em Y minutos por dia, no ambiente que já temos." |
| Próximo passo | "Piloto com um vendedor por 30 dias." |

---

## 9. Riscos e mitigação

| Risco | Impacto | Mitigação |
|---|---|---|
| Cota do Free Edition estoura | Aluno travado ao vivo | Aviso na noite 1, plano B em DuckDB |
| Aula estoura 1h30 | Perde a entrega final | Cortar contexto, nunca entrega |
| Metade da base é iniciante | Abandono na noite 2 | Trilha de fundamentos indicada no grupo |
| Query trava ao vivo | Quebra o ritmo | Resultado pré-computado na célula abaixo |
| Modelo com AUC baixo | Perde credibilidade | Testar antes; o dataset foi calibrado para funcionar |
| Presença cai até a noite 3 | Carrinho abre para sala vazia | .ics, grupo ativo, entrega técnica forte na noite 2 |

---

## 10. Definição de pronto

O projeto está completo quando o aluno tem:

- [ ] Repositório no GitHub com os notebooks das 4 noites
- [ ] `gerar_dataset.py` rodando e produzindo o mesmo dado
- [ ] Bronze, silver e gold no catálogo do Databricks
- [ ] Pipeline agendado com testes de qualidade passando
- [ ] Modelo de propensão treinado, com AUC registrado
- [ ] `score_propensao` versionado como tabela Delta
- [ ] Agente respondendo em cima do score real
- [ ] Job de produção agendado e monitorado
- [ ] README explicando o projeto para quem chegar de fora

---

*Documento de referência da Imersão Jornada de Dados, agosto de 2026.
Dataset: Rota do Perfume, gerado com seed fixa 42.*
