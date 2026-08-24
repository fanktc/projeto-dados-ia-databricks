# 🏗️ Dia 2: Engenharia de dados | Imersão Jornada de Dados

> **Status:** a construir ao vivo na terça, 25/08.

**Promessa da noite:** o projeto passa a rodar sozinho.

Ontem a query quebrou por causa das datas em dois formatos, e a gente resolveu
no braço com um `try_to_date`. Hoje isso vira camada.

## O que entra

| Tema | O que a gente faz |
|---|---|
| **Silver** | A limpeza de verdade: CNPJ nos 3 formatos, data nos 2, dedup por CNPJ, devolução com flag própria |
| **Gold** | `fato_vendas`: uma linha por item vendido, com marca, categoria, receita, custo e margem |
| **Pipeline** | Lakeflow Declarative Pipeline, uma tabela por arquivo |
| **Testes** | Teste que quebra o pipeline **antes** de quebrar o dashboard |

## A sujeira que a noite 1 encontrou, e que hoje some

| Problema | Quantos | Como resolve |
|---|---|---|
| Data em `dd/MM/yyyy` | 3.443 pedidos | `coalesce(try_to_date(...), try_to_date(...))` |
| CNPJ pontuado ou com espaço | 1.334 clientes | `lpad(regexp_replace(cnpj, '[^0-9]', ''), 14, '0')` |
| Mesmo CNPJ, cadastros diferentes | 40 clientes | `row_number()` por CNPJ, mantém o mais antigo |
| Devolução como quantidade negativa | 2.327 itens | coluna `devolucao` própria, valor absoluto à parte |
| Cancelado com valor zerado | 957 pedidos | flag `cancelado` explícita, sem confiar no valor |
| Carteira ativa de vendedor desligado | 441 vínculos | vigência na junção |

## ⚠️ Cuidado que a noite 1 já mediu

O código de exemplo do PRD usa `to_date`. **Em ANSI mode ele aborta a query**
em vez de devolver `NULL` — o correto é `try_to_date`. Isso foi testado no
warehouse.

## ➡️ Depois

Com dado limpo, as três perguntas da diretoria ganham resposta de verdade:
[aula-03](../aula-03-ciencia-de-dados-e-agentes).
