# 📊 KPIs da Aula 1 — Databricks & SQL

Os KPIs abaixo são os que o dado da Rota do Perfume sustenta. Cada um traz a
pergunta de negócio por trás e onde ele é respondido.

---

## 🎯 1. A pergunta da noite

### 1.1 Receita
- **KPI**: Receita total do período · **R$ 102.303.828,05**
- **KPI**: Receita por mês · pico out/2025 (R$ 7,0 mi), vale jan/2026 (R$ 2,5 mi)
- **KPI**: Ticket médio por pedido · **R$ 3.683,70**
- **KPI**: Pedidos faturados vs cancelados · 27.772 contra 957
- **Pergunta**: Quanto a empresa fatura, e o faturamento está subindo?
- **Onde**: `exemplo-04-group-by-receita-no-tempo.sql`

### 1.2 Melhores clientes
- **KPI**: Top 10 clientes por receita
- **KPI**: Clientes distintos com pedido · 2.816 de 3.040 cadastrados
- **Pergunta**: Quem sustenta o faturamento? A quem o comercial deve atenção?
- **Onde**: `exemplo-05-join-melhores-clientes.sql`
- **Cuidado**: agrupar por `razao_social` funde clientes diferentes com o mesmo
  nome. A chave é `cliente_id` — e mesmo ela não resolve os 40 CNPJs duplicados.

---

## 💰 2. Onde a receita se concentra

### 2.1 Marca
- **KPI**: Receita por marca · Layali R$ 18,6 mi contra Attar Real R$ 5,2 mi
- **KPI**: Participação percentual de cada marca (curva ABC)
- **Pergunta**: A receita depende de poucas marcas? Qual o risco disso?

### 2.2 Margem por categoria
- **KPI**: Margem % por categoria · Óleo Concentrado 49,9%, Kit Presente 33,0%
- **KPI**: Receita vs margem — o que vende mais nem sempre é o que ganha mais
- **Pergunta**: A meta do comercial deveria ser faturamento ou margem?

### 2.3 Efeito de lançamento
- **KPI**: Receita de SKUs lançados no período · 47 SKUs, R$ 25,2 mi
- **KPI**: 16% dos produtos respondem por ~25% da receita
- **Pergunta**: Lançamento puxa receita? Vale o esforço de introdução?

**Onde (2.1 a 2.3)**: `exemplo-06-margem-marca-e-sazonalidade.sql`

### 2.4 Sazonalidade
- **KPI**: Índice sazonal por mês do ano
- **KPI**: Meses de pico (abr, jun, out) e de vale (dez, jan)
- **Pergunta**: Quando comprar estoque? Quando reforçar a equipe?
- **Cuidado**: o pico é o mês **anterior** à data comemorativa. E set/2024,
  primeiro mês da base, é artefato de carga — descarte ao ler tendência.

---

## 🤝 3. As três perguntas da diretoria

Quem vai comprar, quem está sumindo e quanto vamos vender são o tema da
[noite 3](../aula-03-ciencia-de-dados-e-agentes) — inclusive as versões que já
respondem em SQL puro, sem modelo.

Elas dependem do que se constrói hoje: sem saber a receita e quem são os
melhores clientes, não há como falar de propensão.

---

## 🧹 4. KPIs de qualidade do dado

Estes não vão para o dashboard do gestor, mas quebram o pipeline antes que ele
minta. Verificados por `99-verificacao.sql`.

| KPI | Valor esperado |
|---|---|
| Datas em `dd/MM/yyyy` | 3.443 (12% dos pedidos) |
| CNPJ com espaço em volta | 223 |
| CNPJ pontuado | 1.111 |
| Clientes com CNPJ duplicado | 40 |
| Itens de devolução (quantidade negativa) | 2.327 |
| Pedidos cancelados com valor zerado | 957 |
| Carteiras vigentes com vendedor desligado | 441 |

**Pergunta**: dá para confiar no número antes de mandar para a diretoria?
