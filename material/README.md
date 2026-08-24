# Dataset Rota do Perfume

Base da Imersão Jornada de Dados — 24 a 27 de agosto de 2026.

**Rota do Perfume** é uma distribuidora B2B de perfumaria árabe. Importa e
distribui no Brasil para perfumarias, farmácias, lojas de shopping, revendedoras
autônomas e e-commerces. Empresa em crescimento acelerado: a receita mais que
dobrou em 24 meses.

Período: setembro/2024 a agosto/2026. Receita total: R$ 102 mi.

## Como gerar

```bash
python gerar_dataset.py --saida ./dados --seed 42
```

Seed fixa: todo mundo gera exatamente o mesmo dado. Sem dependências externas.

## Estrutura

### ERP — o que foi vendido

| Arquivo | Linhas | O que tem |
|---|---|---|
| `produtos.csv` | 292 | SKU, categoria, marca, **nota olfativa**, preço, custo, **data de lançamento** |
| `pedidos.csv` | 28.729 | cliente, vendedor, data, canal, status, valor total |
| `itens_pedido.csv` | 197.724 | SKU, quantidade, preço praticado, desconto, valor |
| `pagamentos.csv` | 27.772 | forma, parcelas, taxa, vencimento, pagamento, status |
| `estoque.csv` | 8.400 | snapshot semanal por SKU, com flag de ruptura |

### CRM — para quem vendemos

| Arquivo | Linhas | O que tem |
|---|---|---|
| `clientes.csv` | 3.040 | CNPJ, razão social, segmento, cidade, bairro, cadastro |
| `vendedores.csv` | 42 | nome, região, admissão, desligamento, meta |
| `carteira.csv` | 3.637 | vínculo vendedor ↔ cliente, com histórico |
| `oportunidades.csv` | 5.979 | funil: origem, etapa, valor, ciclo, motivo de perda |
| `visitas.csv` | 37.936 | data, resultado, duração |

## O que esse setor tem de diferente

**Quatro picos de sazonalidade, não um.** O varejo compra *antes* da data, então
o pico da distribuidora é o mês anterior:

| Mês | O que acontece |
|---|---|
| Abril | Reposição para o Dia das Mães |
| Junho | Dia dos Namorados |
| Outubro | Reposição para a Black Friday |
| Dezembro e janeiro | Vale de vendas — o varejo já está abastecido |

**Lançamento gera pico.** 47 SKUs foram lançados no período e responderam por
R$ 25,5 mi — 25% da receita com 16% dos produtos. Dá para medir o efeito nos
120 dias seguintes ao lançamento.

**Marca importa muito.** Layali fez R$ 18,6 mi, Attar Real fez R$ 5,2 mi.
Curva ABC de marca é uma análise natural aqui.

**Margem varia muito por categoria:** Óleo Concentrado 49,9%, Kit Presente 33,0%.
Vender mais nem sempre é ganhar mais.

**Ruptura dói mais que em bebida.** Quando esgota o perfume da moda, a venda
não migra para outro — ela some. 11% dos snapshots têm saldo zero.

## A sujeira é proposital

A limpeza é o conteúdo da noite 2.

1. CNPJ em três formatos: puro, pontuado e com espaço em volta
2. Razão social às vezes em CAIXA ALTA, às vezes sem acento
3. Data de cadastro misturando ISO e `dd/mm/aaaa`
4. ~40 clientes duplicados com id novo e CNPJ escrito diferente
5. SKU descontinuado ainda aparecendo em pedido
6. Devolução gravada como quantidade negativa
7. Pedido cancelado com `valor_total` zerado, sem flag óbvia
8. ~12% das datas de pedido em formato brasileiro
9. Vendedor desligado com carteira ainda vinculada
10. Ruptura de estoque em ~11% dos snapshots

## O que dá para construir

| Noite | Análise |
|---|---|
| 1 | Receita no tempo, top clientes, top marcas |
| 2 | Limpeza, medallion, pipeline, testes |
| 3 | Propensão de compra, score versionado, agente de IA |
| 4 | Deploy, monitoramento, custo |

Também: efeito de lançamento na receita, margem por categoria e por marca,
ruptura versus venda perdida, prazo médio de recebimento, conversão do funil
por origem, produtividade por vendedor e análise de mix por nota olfativa.

## Tamanho

~14 MB descompactado. Cabe no Databricks Free Edition sem estourar a cota.
