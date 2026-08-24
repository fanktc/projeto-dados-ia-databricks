# 🏗️ Dia 2: Engenharia de dados | Imersão Jornada de Dados

> **Status:** construído ao vivo na terça, 25/08. Este README é o mapa da noite.

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
| 01 | `exemplo-01-silver-clientes.sql` | CNPJ normalizado, razão social padronizada, dedup |
| 02 | `exemplo-02-silver-pedidos.sql` | Data resolvida, tipos certos, flag de cancelado |
| 03 | `exemplo-03-silver-itens.sql` | Devolução sinalizada, SKU descontinuado marcado |
| 04 | `exemplo-04-gold-fato-vendas.sql` | Uma linha por item, com marca, categoria, receita, custo e margem |
| 05 | `exemplo-05-pipeline-declarativo.py` | As mesmas transformações como pipeline, uma tabela por arquivo |
| 06 | `exemplo-06-testes-de-qualidade.sql` | O teste que quebra antes do dashboard |

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

| Teste | Esperado |
|---|---|
| CNPJ único na silver | 0 duplicados (eram 40) |
| Nenhuma data nula | 0 (os 3.443 do formato BR foram convertidos) |
| Nenhuma receita negativa na gold | 0 (as 2.327 devoluções ficaram de fora) |
| Volume da `fato_vendas` | entre 150.000 e 260.000 linhas |
| Nenhum pedido órfão | todo pedido da gold existe na silver |
| Receita total preservada | R$ 102.303.828,05, igual à da noite 1 |

O último é o mais importante: **limpeza não pode mudar o faturamento**. Se
mudou, você jogou dado fora sem querer.

---

## ➡️ Amanhã

Com a `gold.fato_vendas` de pé, as três perguntas da diretoria deixam de ser
consulta e viram modelo: [aula-03](../aula-03-ciencia-de-dados-e-agentes).
