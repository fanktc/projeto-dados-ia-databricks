# Imersão Jornada de Dados — 24 a 27 de agosto de 2026

Projeto de uma área de dados e vendas construída do zero, ao vivo, em 4 noites.
Empresa fictícia: **Rota do Perfume** — distribuidora B2B de bebidas e
alimentos que vende para bares, restaurantes, mercadinhos e padarias.

## Contexto

Assumimos o papel de um analista de dados recém-contratado pela Rota do Perfume.
A diretoria comercial quer responder três perguntas:

1. Quem vai comprar? (propensão)
2. Quem está sumindo? (churn)
3. Quanto vamos vender? (previsão)

## Stack

- **Databricks Free Edition** (serverless) — ambiente principal
- **Python** e **SQL**
- **Delta Lake** e Unity Catalog
- **Claude Code** para construir
- **DuckDB** como plano B local se o Databricks travar

## Estrutura das 4 noites

| Noite | Data | Tema | Entregável |
|---|---|---|---|
| 1 | 24/08 | Objetivo e análise | Ambiente rodando, primeira análise em 4 ferramentas |
| 2 | 25/08 | Engenharia de dados | Medallion, pipeline agendado, testes |
| 3 | 26/08 | Ciência de dados e agentes | Modelo de propensão e agente de IA |
| 4 | 27/08 | Deploy e próximos passos | Projeto no ar e monitorado |

## Dataset

Gerado por `gerar_dataset.py --saida ./dados --seed 42`. Seed fixa: todos os
alunos têm exatamente o mesmo dado. Período: setembro/2024 a agosto/2026.

### ERP — `dados/erp/`

| Arquivo | Linhas | Chave | Colunas |
|---|---|---|---|
| `produtos.csv` | 292 | `sku` | descricao, categoria, marca, nota_olfativa, preco_tabela, custo_unitario, unidade, ativo, data_lancamento |
| `pedidos.csv` | 28.729 | `pedido_id` | cliente_id, vendedor_id, data_pedido, canal, status, valor_total |
| `itens_pedido.csv` | 197.724 | `item_id` | pedido_id, sku, quantidade, preco_praticado, desconto_pct, valor_bruto |
| `pagamentos.csv` | 27.772 | `pagamento_id` | pedido_id, forma_pagamento, parcelas, valor, taxa_pct, valor_liquido, data_vencimento, data_pagamento, status_pagamento |
| `estoque.csv` | 8.400 | `data_snapshot`+`sku` | saldo, ruptura |

### CRM — `dados/crm/`

| Arquivo | Linhas | Chave | Colunas |
|---|---|---|---|
| `clientes.csv` | 3.040 | `cliente_id` | cnpj, razao_social, segmento, cidade, uf, bairro, data_cadastro, ativo |
| `vendedores.csv` | 42 | `vendedor_id` | nome, regiao, uf, data_admissao, data_desligamento, meta_mensal |
| `carteira.csv` | 3.637 | `carteira_id` | cliente_id, vendedor_id, data_inicio, data_fim |
| `oportunidades.csv` | 5.979 | `oportunidade_id` | cliente_id, vendedor_id, origem, data_abertura, etapa, probabilidade_pct, valor_estimado, data_fechamento, ciclo_dias, motivo_perda |
| `visitas.csv` | 37.936 | `visita_id` | cliente_id, vendedor_id, data_visita, resultado, duracao_min |

### Relacionamentos

```
clientes 1─N pedidos 1─N itens_pedido N─1 produtos
clientes 1─N oportunidades
clientes 1─N visitas
clientes N─N vendedores  (via carteira, com vigência)
pedidos  1─1 pagamentos
```

## A sujeira é proposital

**Não "conserte" o gerador.** A limpeza é o conteúdo da noite 2.

1. CNPJ em 3 formatos: puro, pontuado (`00.000.000/0000-00`) e com espaço em volta
2. Razão social às vezes em CAIXA ALTA, às vezes sem acento
3. `data_cadastro` misturando ISO e `dd/mm/aaaa`
4. ~40 clientes duplicados: id novo, mesmo CNPJ escrito diferente
5. SKU descontinuado (`ativo='N'`) ainda aparecendo em pedido
6. Devolução gravada como `quantidade` negativa
7. Pedido cancelado com `valor_total = 0`, sem flag no item
8. ~12% das datas de pedido em `dd/mm/aaaa`
9. Vendedor desligado com carteira ainda vinculada
10. Ruptura de estoque (`saldo = 0`) em ~11% dos snapshots

## Comportamento esperado do dado

- **Quatro picos de sazonalidade**, não um. O varejo compra ANTES da data, então
  o pico da distribuidora é o mês anterior: abril (Dia das Mães), junho (Namorados),
  outubro (Black Friday). Dezembro e janeiro são vale.
- **Outubro/2025 fez R$ 7,0 mi · janeiro/2026 fez R$ 2,5 mi**
- **Receita total 24 meses:** R$ 102 mi · ticket médio por pedido R$ 3.684
- **Crescimento acelerado:** a receita mais que dobrou no período
- **Lançamento gera pico:** 47 SKUs lançados = R$ 25,5 mi (25% da receita com 16% dos SKUs)
- **Marca concentra:** Layali R$ 18,6 mi contra Attar Real R$ 5,2 mi
- **Margem varia muito:** Óleo Concentrado 49,9% contra Kit Presente 33,0%
- **Segunda e terça** concentram pedido; fim de semana é quase nulo
- **~11% dos clientes** entram em churn

## Convenções do projeto

- Nomes de tabela e coluna em **snake_case e português**, como no CSV
- Catálogo Databricks: `rota_perfume`
- Schemas: `bronze`, `silver`, `gold` (medallion)
- Camada bronze preserva o dado como veio, sujeira inclusa
- Camada silver é onde a limpeza acontece
- Camada gold é modelada para consumo: fatos e dimensões
- Notebooks em `notebooks/`, nomeados `n1_`, `n2_`, `n3_`, `n4_` por noite
- SQL avulso em `sql/`

## Ao trabalhar neste projeto

- Comente o código pensando em quem está assistindo ao vivo pela primeira vez
- Prefira SQL legível a SQL esperto — a aula é sobre entender, não impressionar
- Nunca gere números aleatórios em análise: o dado é fixo por seed e o aluno
  precisa chegar no mesmo resultado
- Ao analisar sazonalidade, lembre que o pico é o mês ANTERIOR à data comemorativa
- Ao criar queries de exemplo, use o caminho completo: `rota_perfume.silver.pedidos`
- O ambiente é Free Edition: evite qualquer coisa que exija cluster dedicado
- Ao mexer em datas, lembre que existem dois formatos misturados na origem
