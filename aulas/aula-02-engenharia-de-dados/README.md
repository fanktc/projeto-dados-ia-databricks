# 🏗️ Dia 2: Engenharia de dados | Imersão Jornada de Dados

> **Status:** os 7 exemplos estão prontos e **rodados no workspace**. A silver,
> a gold e os três marts existem. Os 9 testes passam.

Ontem a query quebrou por causa das datas em dois formatos, e a gente resolveu
no braço com um `try_to_date` dentro do `SELECT`. Funcionou — para uma query.

Hoje isso vira **camada**: escrito uma vez, testado, agendado, e todo mundo que
consultar o dado depois já pega ele limpo.

> **Promessa da noite:** o projeto passa a rodar sozinho.
> **Pergunta da noite:** *"Como faço para não resolver o mesmo problema toda vez?"*
> **Conexão:** a `gold.fato_vendas` que sai daqui é a tabela que a
> [aula-03](../aula-03-ciencia-de-dados-e-agentes) usa para treinar o modelo.

---

## 🧠 Antes de tudo: por que três camadas?

A tentação é limpar o dado na entrada e pronto. O problema aparece no primeiro
número errado: sem o original, não dá para saber se o erro veio da origem ou
da sua limpeza.

```
  BRONZE                SILVER                 GOLD
  como veio             limpo e tipado         modelado para consumo

  tudo texto            data é DATE            uma linha por item vendido
  CNPJ nos 3 formatos   CNPJ com 14 dígitos    já com marca, margem e mês
  sujeira preservada    duplicado resolvido    é o que o dashboard lê
```

Cada camada responde a uma pergunta diferente:

- **bronze** — "o que a origem mandou?" É a prova. Nunca se edita.
- **silver** — "qual é o dado correto?" Uma linha por entidade real.
- **gold** — "como o negócio quer ver?" Fato e dimensão, pronto para agregar.

---

## 🧹 A sujeira que a noite 1 encontrou, e que hoje some

Cada item aqui foi **medido** na aula 1, não estimado:

| Problema | Quantos | Como a silver resolve |
|---|---|---|
| Data em `dd/MM/yyyy` | 3.443 pedidos (12%) | `coalesce(try_to_date(c,'yyyy-MM-dd'), try_to_date(c,'dd/MM/yyyy'))` |
| CNPJ pontuado | 1.111 clientes | `regexp_replace(cnpj, '[^0-9]', '')` |
| CNPJ com espaço em volta | 223 clientes | `trim()` antes de tudo |
| CNPJ com zero à esquerda | 309 clientes | `lpad(..., 14, '0')` — e nunca converter para número |
| Mesmo CNPJ, cadastros diferentes | 40 clientes | `row_number()` por CNPJ, mantém o cadastro mais antigo |
| Devolução como quantidade negativa | 2.327 itens | coluna `devolucao` própria + `abs(quantidade)` |
| Cancelado com valor zerado | 957 pedidos | flag `cancelado` explícita, sem confiar no valor |
| SKU descontinuado em pedido | 76 itens | join com produtos, coluna `sku_descontinuado` |
| Carteira ativa de vendedor desligado | 441 vínculos | vigência na junção, não só `data_fim IS NULL` |

---

## 🎯 Roteiro da noite

```
  Limpar                      Modelar              Automatizar
  (01 → 02 → 03)              (04)                 (05 → 06)

  clientes, pedidos           fato_vendas          pipeline declarativo
  e itens viram silver        com margem           e testes de qualidade
```

| # | Arquivo | O que faz |
|---|---|---|
| 01 | `exemplo-01-silver-clientes.sql` | CNPJ normalizado, razão social padronizada, dedup por CNPJ |
| 02 | `exemplo-02-silver-pedidos.sql` | Data resolvida, tipos certos, flag de cancelado |
| 03 | `exemplo-03-silver-itens-e-produtos.sql` | Devolução sinalizada, SKU descontinuado marcado |
| 04 | `exemplo-04-silver-crm-e-financeiro.sql` | Vendedores, carteira, visitas, funil e pagamentos |
| 05 | `exemplo-05-gold-dimensoes-e-fato.sql` | 4 dimensões conformadas + `fato_vendas` |
| 06 | `exemplo-06-data-marts-por-diretoria.sql` | Vendas, produto e financeiro sobre o mesmo fato |
| 07 | `exemplo-07-testes-de-qualidade.sql` | Os 9 testes que quebram antes do dashboard |

## 🏛️ Data marts: um por diretoria, um fato só

O erro clássico é criar um **fato por área** — `fato_vendas_comercial` e
`fato_vendas_produto`. Em três meses eles divergem e ninguém sabe qual está certo.

O que separa um mart do outro é a **dimensão dominante** e as **métricas**, não
a tabela base:

```
gold/
├── dim_cliente · dim_produto · dim_vendedor · dim_calendario   (conformadas)
├── fato_vendas          grão: item de pedido não cancelado
│
├── mart_vendas_por_vendedor      vendedor  → meta, carteira, produtividade
├── mart_vendas_funil             origem    → conversão, ciclo, motivo de perda
├── mart_produto_performance      SKU       → mix, margem, curva ABC
└── mart_financeiro_recebimento   vencimento→ caixa, atraso, custo de taxa
```

| Diretoria | O que só ela pergunta | Coluna que só ela usa |
|---|---|---|
| **Vendas** | "qual vendedor está abaixo da meta?" | `meta_mensal`, `etapa` |
| **Produto** | "vendo o dobro e ganho menos — mudo o mix?" | `custo_unitario` |
| **Financeiro** | "quanto entra em caixa em 30 dias?" | `data_vencimento`, `taxa_pct` |

As três somam **o mesmo R$ 102.303.828,05**. É isso que "conformado" significa.

> **E supply?** Parece natural, mas o dado não sustenta: cada SKU aparece em
> só 28,8 das 105 semanas de snapshot (27,4% de cobertura). Dá para taxa de
> ruptura agregada, não para giro por produto. É um bom exemplo de quando a
> resposta honesta para a diretoria é "com esse dado, não".

---

## ⚠️ Duas armadilhas já medidas no warehouse

**1. `to_date` aborta a query.** O código de exemplo do PRD usa
`coalesce(to_date(...), to_date(...))`. Em ANSI mode — que é o padrão do
Databricks SQL — a data malformada levanta exceção em vez de virar `NULL`, e
derruba tudo. Use **`try_to_date`**.

**2. Não deixe o Spark adivinhar tipo na bronze.** `inferSchema=true`
transformaria o CNPJ em número e apagaria os 309 zeros à esquerda. Na silver
você converte de propósito, sabendo o que está fazendo.

---

## 🔢 Os testes que precisam passar

| # | Teste | Resultado |
|---|---|---|
| 1 | Receita preservada da bronze até a gold | R$ 102.303.828,05 ✓ |
| 2 | CNPJ único na silver | 0 duplicados (eram 40) ✓ |
| 3 | Nenhuma data nula em pedidos | 0 (3.443 convertidos) ✓ |
| 4 | Receita negativa só em devolução | 0 fora de devolução ✓ |
| 5 | Volume da `fato_vendas` | 191.080 linhas ✓ |
| 6 | Nenhum pedido órfão no fato | 0 ✓ |
| 7 | Nenhum cliente órfão no fato | 0 ✓ |
| 8 | Mart de produto bate com o fato | R$ 102.303.828,05 ✓ |
| 9 | Todo CNPJ com 14 dígitos | 0 malformados ✓ |

O primeiro é o que mais importa: **limpeza não pode mudar o faturamento**. Se
mudou, você jogou dado fora sem querer.

### 🔍 A armadilha que quase passou

A primeira versão do `fato_vendas` deixava a devolução **de fora** — parecia
certo, "receita é o que vendeu". O resultado: a gold mostrava R$ 103,6 mi e a
silver R$ 102,3 mi.

R$ 1,26 milhão de diferença entre duas camadas do mesmo pipeline. Um dia alguém
compara os relatórios e a discussão vira sobre qual sistema está certo.

A devolução ficou **dentro do fato**, com flag e valor negativo:

```sql
SUM(receita)                                  -- R$ 102,3 mi, igual à silver
SUM(receita) FILTER (WHERE NOT devolucao)     -- R$ 103,6 mi, o bruto vendido
```

Quem quer cada número tem como pedir, e os dois reconciliam.

---

## ➡️ Amanhã

Com a `gold.fato_vendas` de pé, as três perguntas da diretoria deixam de ser
consulta e viram modelo: [aula-03](../aula-03-ciencia-de-dados-e-agentes).
