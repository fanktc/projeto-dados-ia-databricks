# Prompt 4 · Gold — os data marts e os testes que quebram o pipeline

**Entrega:** dimensões conformadas, `fato_vendas`, três marts por diretoria e
os 9 testes de qualidade que interrompem o job. **Deploy nº 4.**

> A Gold não é "a camada limpa" — isso é a silver. A Gold é a camada **modelada
> para um consumidor específico**. Se você não sabe quem consome, não está
> pronto para criar Gold.

**Enquanto ele trabalha, você explica:**

- **O contrato vem antes do SQL.** Granularidade, dimensões, métricas e filtros
  definidos **antes** da primeira linha. `fato_vendas` tem grão de *item de
  pedido* — escrever isso numa frase evita seis meses de discussão.
- **Um fato, vários marts.** O erro clássico é criar `fato_vendas_comercial` e
  `fato_vendas_produto`. Em três meses eles divergem e ninguém sabe qual está
  certo. O que separa um mart do outro é a **dimensão dominante** e as
  **métricas**, nunca a tabela base.
- **Conformado significa que somam igual.** Os três marts têm que fechar no
  mesmo R$ 102.303.828,05. É esse o significado da palavra.
- **Teste que não quebra o job não é teste, é relatório.** Se a verificação
  falha e o pipeline segue, o dashboard mostra número errado com cara de certo.

---

## O prompt

```
Continue o bundle em aulas/aula-02-engenharia-de-dados/rotaperfume/.
A silver está limpa e com contrato. Agora a gold: modelar para consumo.

Crie em src/gold/, em SQL, lendo SÓ da silver — nunca da bronze.

05-dimensoes.sql — quatro dimensões conformadas
  gold.dim_cliente    uma linha por cliente: segmento, cidade, uf, data de
                      cadastro, data do primeiro e do último pedido, total de
                      pedidos, receita acumulada, dias desde a última compra
  gold.dim_produto    uma linha por SKU: marca, categoria, nota olfativa,
                      custo, preço de tabela, data de lançamento, descontinuado
  gold.dim_vendedor   uma linha por vendedor: região, meta mensal, ativo
  gold.dim_calendario uma linha por dia dos 24 meses: ano, mes, nome do mês,
                      trimestre, dia da semana, e a coluna mes_pico_setor
                      (abril, junho e outubro = TRUE)

06-fato-vendas.sql — o contrato, escrito antes do SQL num comentário no topo
  Granularidade: uma linha por ITEM de pedido
  Filtro: exclua pedidos cancelados. NÃO exclua devolução.
  Dimensões: data_pedido, ano, mes, canal, cliente_id, razao_social, segmento,
             cidade, vendedor_id, sku, categoria, marca, nota_olfativa
  Métricas:  quantidade, preco_praticado, receita, custo, margem, devolucao
  custo  = quantidade * custo_unitario do produto
  margem = receita - custo
  Devolução entra com quantidade e receita NEGATIVAS, com a flag devolucao.
  Particione por ano e mes.

  POR QUE A DEVOLUÇÃO FICA DENTRO: se ela ficar de fora, a gold soma
  R$ 103,6 mi e a silver R$ 102,3 mi. R$ 1,26 milhão de diferença entre duas
  camadas do mesmo pipeline. Quem quiser o bruto pede:
    SUM(receita) FILTER (WHERE NOT devolucao)

07-marts.sql — um mart por diretoria, todos sobre o MESMO fato
  gold.mart_vendas_por_vendedor   grão vendedor × mês: receita, margem, meta,
                                  atingimento, clientes atendidos, ticket médio
  gold.mart_produto_performance   grão SKU × mês: receita, margem, margem %,
                                  quantidade, curva ABC por receita acumulada
  gold.mart_financeiro_recebimento grão mês de vencimento: valor a receber,
                                  recebido, atraso médio, custo de taxa

COMMENT em TODAS as tabelas, e em TODAS as colunas de fato_vendas, explicando
o significado de NEGÓCIO, não o técnico. Por exemplo, em margem:
"Receita menos custo do produto. Não considera desconto comercial nem frete."
Nas dimensões, comente as colunas que exigiram decisão (dias_sem_comprar,
mes_pico_setor); cidade e uf se explicam sozinhas.
Isso não é capricho: é o que o Genie lê no prompt 6 para escolher a coluna
certa. Coluna sem comentário é coluna que ele usa errado, com confiança.

08-testes.sql — os 9 testes, cada um levantando exceção com raise_error()
quando falhar, para o job PARAR:
  1. receita da gold = receita da silver = R$ 102.303.828,05 (tolerância 0,01)
     Esse é o teste que mais importa: limpeza NÃO PODE mudar o faturamento.
  2. CNPJ único na silver.clientes (0 duplicados)
  3. nenhuma data_pedido nula na silver.pedidos
  4. receita negativa só onde devolucao = true
  5. volume da gold.fato_vendas entre 140.000 e 250.000 linhas
  6. nenhum pedido_id na gold que não exista na silver.pedidos
  7. nenhum cliente_id na gold que não exista na silver.clientes
  8. mart_produto_performance soma o mesmo que fato_vendas
  9. todo CNPJ com exatamente 14 dígitos
  Cada teste imprime nome, valor calculado, valor esperado e passou/falhou.

Acrescente ao resources/pipeline.job.yml:
  gold_dimensoes   depends_on: as quatro tarefas silver
  gold_fato_vendas depends_on: gold_dimensoes
  gold_marts       depends_on: gold_fato_vendas
  testes           depends_on: gold_marts   ← por último, e obrigatório

Rode e me mostre a saída:
  databricks bundle deploy --target dev --profile projeto-dados-ia
  databricks bundle run rotaperfume_pipeline --target dev --profile projeto-dados-ia

Os 9 testes precisam passar. Se algum falhar, corrija a transformação —
nunca o teste.
```

---

## O momento que fecha o arco da noite 1

```sql
SELECT marca, ROUND(SUM(receita)/1e6, 1) AS receita_mi
FROM lakehouse_rotaperfume.gold.fato_vendas
GROUP BY marca ORDER BY 2 DESC LIMIT 5;
-- Layali 18,6 · ... · Attar Real 5,2
```

Compare com o `exemplo-06` de ontem, que precisou de três `JOIN` e dois `CAST`
para chegar no mesmo número.

---

## Fala de aula

> *"Ontem eu levei quinze minutos escrevendo query para chegar nesse número.
> Agora é `SELECT marca, SUM(receita)` — cinco segundos. E, mais importante:
> sai igual para todo mundo da empresa, para sempre, porque a regra de margem
> está escrita numa tabela e não na cabeça de quem escreveu a query.*
>
> *E olha o último bloco: nove testes. O primeiro é o que mais importa — a
> receita da gold tem que ser exatamente a da silver. Se um dia alguém mexer
> numa transformação e o número mudar, o job **quebra**, e o dashboard fica com
> o dado de ontem. Que é infinitamente melhor do que ficar com o dado errado
> de hoje."*


---

## O que tem que aparecer na tela

| Número | Valor |
|---|---|
| Linhas na `fato_vendas` | **191.080** |
| Receita (com devolução) | **R$ 102.303.828,05** — igual à silver |
| Bruto vendido (`FILTER (WHERE NOT devolucao)`) | R$ 103.568.586,35 |
| Diferença entre os dois | R$ 1,26 mi — a devolução |
| Margem total | R$ 41.125.619,86 (40,2%) |
| Layali (marca líder) | R$ 18,4 mi líquido · R$ 18,6 mi bruto |
| Kit Presente | margem 33,0% — a pior |
| Óleo Concentrado | margem 49,9% — a melhor |
| Outubro/2025 · Janeiro/2026 | R$ 7,02 mi · R$ 2,46 mi |

Os três marts e o fato somam **exatamente o mesmo** R$ 102.303.828,05. É isso
que a palavra "conformado" significa, e é o teste 8.

---

## Se der errado ao vivo

| Sintoma | Causa | Correção em um prompt |
|---|---|---|
| A gold soma R$ 103,6 mi e a silver R$ 102,3 mi | A devolução ficou de fora do fato | *"Traga a devolução para dentro do fato, com valor negativo e flag."* |
| `raise_error` reclama de tipo | Ele retorna tipo `NOTHING` | Use dentro de `CASE WHEN ... THEN 'PASSOU' ELSE raise_error(...) END` |
| O fato tem mais linhas que o esperado | Faltou excluir pedido cancelado | `WHERE NOT p.cancelado` |
| Um teste falhou | **Ótimo. É para isso que ele existe.** | Corrija a transformação, **nunca** o teste |

**Tempo medido:** ~40s de deploy, ~2min40 do pipeline inteiro com 10 tarefas.
