# Prompt 1 · Features — a parte que vale dinheiro

**Entrega:** `gold.features_treino` e `gold.features_cliente`, geradas pela
mesma função com datas diferentes. **Deploy nº 1 da noite.**

> A tentação é começar pelo modelo. Comece pelas features: o modelo é o mesmo
> `.fit()` para todo mundo, e é aqui que sai a diferença entre um projeto que
> funciona e um que impressiona no notebook e morre em produção.

---

## O que mostrar antes

**1 · A gold sabe tudo sobre ontem e nada sobre amanhã**

```sql
-- 191.080 linhas de tudo que já aconteceu
SELECT COUNT(*) AS linhas, ROUND(SUM(receita), 2) AS receita
FROM lakehouse_rotaperfume.gold.fato_vendas;

-- e a pergunta que ela NÃO responde:
-- "quais desses 3.000 clientes compram no mês que vem?"
SELECT COUNT(*) FROM lakehouse_rotaperfume.gold.dim_cliente;
```

> *"Tudo que a gente construiu em duas noites responde no passado. Hoje o
> pipeline passa a responder no futuro — e a primeira coisa que muda não é o
> modelo, é o formato do dado."*

**2 · O formato que o modelo precisa, e que a gold não tem**

```sql
-- o fato tem uma linha por ITEM. O modelo precisa de uma linha por CLIENTE.
SELECT cliente_id, COUNT(*) AS linhas_no_fato
FROM lakehouse_rotaperfume.gold.fato_vendas
GROUP BY cliente_id ORDER BY 2 DESC LIMIT 5;
```

> *"Modelo não come tabela fato. Ele come uma linha por coisa que você quer
> prever, com todas as colunas na mesma linha. Isso tem nome: feature."*

**3 · A pergunta que abre a discussão do ponto de corte**

Faça esta pergunta para a sala **antes** de colar o prompt:

> *"Se eu quero prever quem compra nos próximos 30 dias, posso usar a receita
> total do cliente como coluna?"*

A resposta quase sempre é "pode". E ela está errada se a receita total incluir
os 30 dias que a gente quer prever. **É esse mal-entendido que o prompt vai
resolver com uma linha de código e uma coluna de auditoria.**

---

**Enquanto ele trabalha, você explica:**

- **Feature é conhecimento de negócio virando coluna.** `recencia_dias` está em
  qualquer tutorial. `atraso_relativo` — recência dividida pelo intervalo médio
  *do próprio cliente* — não está em nenhum, porque depende de saber que
  distribuição funciona por ciclo de reposição.
- **A data de corte é a espinha do arquivo.** Toda feature é calculada com
  dado anterior a uma data que entra por parâmetro. Não é disciplina pessoal,
  é assinatura de função.
- **Uma função, dois usos.** A mesma `montar_features()` gera o dado de treino
  (com rótulo) e o dado de score (sem rótulo). É impossível os dois divergirem
  — e esse desencontro tem nome, *training/serving skew*, e é o problema que o
  Feature Store resolve com infraestrutura. Aqui está resolvido com um `def`.
- **Tabela de feature é gold.** Ela é comentada, testada e auditada como
  qualquer outra. A auditoria de metadado de ontem continua valendo, e quebra
  o job se faltar `COMMENT`.

---

## O prompt

```
Continue o bundle em aulas/aula-02-engenharia-de-dados/rotaperfume/.
A gold está pronta, testada e com metadado auditado. Começa a camada de ML.

1. src/ml/11-features.py — um notebook Python (serverless).

   Defina UMA função montar_features(referencia) que devolve uma linha por
   cliente com tudo que se sabia dele ATÉ essa data. Toda fonte tem que ser
   filtrada por data < referencia logo na primeira linha — nenhuma exceção.

   Features, em três grupos:

   RFM e comportamento de compra (de gold.fato_vendas)
     recencia_dias, frequencia_pedidos, valor_total, margem_total,
     skus_distintos, categorias_distintas, marcas_distintas, canais_distintos,
     devolucoes, meses_de_casa, pedidos_por_mes, ticket_medio

   Ritmo (janela sobre fato_vendas)
     intervalo_medio_dias e intervalo_desvio — dias entre pedidos consecutivos
     receita_90d e peso_90d — quanto da receita do cliente é recente

   CRM (de silver.visitas e silver.oportunidades)
     visitas, visitas_com_pedido, taxa_conversao_visita,
     oportunidades, oportunidades_ganhas

   E a feature derivada que mais importa:
     atraso_relativo = recencia_dias / max(intervalo_medio_dias, 1)
     Um cliente que compra a cada 7 dias e sumiu há 20 está em risco. Um que
     compra a cada 90 e sumiu há 20 está normal. A recência sozinha não
     distingue os dois; esta coluna sim.

2. Use a função DUAS vezes e grave duas tabelas:

   gold.features_treino    referencia 2026-08-01, com a coluna comprou_30d:
                           1 se o cliente fez pedido entre 01/08 e 31/08
   gold.features_cliente   referencia 2026-08-31 (fim da base), sem rótulo.
                           É a tabela que o modelo vai pontuar.

   Grave também uma coluna _referencia com a data de corte de cada linha.

3. CUIDADOS QUE FAZEM A TAREFA SEGUINTE FALHAR SE FOREM IGNORADOS:
   a) CAST para DOUBLE em toda soma de receita e margem. A gold usa
      DECIMAL(18,2), Decimal não serializa em JSON, e o registro do modelo
      quebra com "Object of type Decimal is not JSON serializable".
   b) Cliente com um pedido só não tem intervalo entre pedidos. Preencha com
      999 (nunca voltou), nunca com 0 (voltou no mesmo dia).
   c) Nada de current_date(). A base termina em 2026-08-31 e a seed é fixa:
      todo aluno tem que chegar no mesmo número.

4. COMMENT em cada coluna das duas tabelas, e COMMENT ON TABLE nas duas.
   A auditoria de metadado do pipeline quebra o job se faltar.

5. Ao final do notebook, imprima quantos clientes e qual a taxa de positivos,
   e levante ValueError se a taxa sair fora de 5%–95%: rótulo desequilibrado
   torna o modelo inútil e é melhor descobrir agora.

6. Acrescente a tarefa ml_features ao rotaperfume_pipeline, dependendo de
   testes_de_qualidade — não faz sentido treinar em cima de dado que não
   passou na conferência.

7. Rode:
   databricks bundle validate --target dev --profile projeto-dados-ia
   databricks bundle deploy   --target dev --profile projeto-dados-ia
   databricks bundle run rotaperfume_pipeline --target dev --profile projeto-dados-ia
```

---

## Como verificar a feature

**1 · As duas tabelas existem e têm o mesmo formato**

```sql
SELECT 'features_treino'  AS tabela, COUNT(*) AS clientes,
       MIN(_referencia) AS referencia FROM lakehouse_rotaperfume.gold.features_treino
UNION ALL
SELECT 'features_cliente', COUNT(*), MIN(_referencia)
FROM lakehouse_rotaperfume.gold.features_cliente;
-- 2.815 clientes na de treino (referência 2026-08-01)
-- 2.816 na de score (referência 2026-08-31) — um cliente a mais, que fez o
--        primeiro pedido em agosto e ainda não existia no corte de treino
```

**2 · O rótulo está equilibrado**

```sql
SELECT COUNT(*) AS clientes,
       SUM(comprou_30d) AS compraram,
       ROUND(AVG(comprou_30d), 4) AS taxa
FROM lakehouse_rotaperfume.gold.features_treino;
-- 2.815 · 1.123 · 0,3989
```

> *"40% compraram nos 30 dias seguintes. Esse número importa: se fosse 3%,
> chutar 'ninguém compra' acertaria 97% das vezes e o modelo não teria o que
> aprender."*

**3 · A prova de que não há vazamento — a query que fecha a discussão**

```sql
-- Nenhum cliente pode ter recência negativa: isso significaria que a última
-- compra dele é POSTERIOR à data de corte, ou seja, a feature enxergou o
-- futuro que o rótulo mede.
SELECT COUNT(*) AS clientes_com_recencia_negativa
FROM lakehouse_rotaperfume.gold.features_treino
WHERE recencia_dias < 0;
-- 0. A menor recência da tabela é 1 dia. Se der qualquer outro número, tem vazamento.
```

```sql
-- E a checagem direta: a maior data usada nas features é anterior ao corte?
SELECT MAX(data_pedido) AS ultima_compra_considerada
FROM lakehouse_rotaperfume.gold.fato_vendas
WHERE data_pedido < '2026-08-01';
-- 2026-07-31. O rótulo começa em 2026-08-01. Elas não se tocam.
```

**4 · A feature da noite, olhada de perto**

```sql
-- atraso_relativo separa dois clientes que a recência confunde
SELECT razao_social, recencia_dias,
       ROUND(intervalo_medio_dias, 1) AS compra_a_cada,
       ROUND(atraso_relativo, 2)      AS atraso_relativo,
       comprou_30d
FROM lakehouse_rotaperfume.gold.features_treino f
JOIN lakehouse_rotaperfume.gold.dim_cliente c USING (cliente_id)
WHERE recencia_dias BETWEEN 18 AND 22
ORDER BY atraso_relativo DESC
LIMIT 10;
```

> Mostre duas linhas com **a mesma recência** e `atraso_relativo` muito
> diferente. *"Os dois sumiram há 20 dias. Para um deles isso é rotina; para o
> outro é o dobro do que ele costuma demorar. A recência não sabe a diferença.
> Esta coluna sabe — e amanhã ela vai ser a que o modelo mais usa."*

**5 · O metadado passou na auditoria de ontem**

```sql
SELECT table_name, COUNT(*) AS colunas_sem_comentario
FROM lakehouse_rotaperfume.information_schema.columns
WHERE table_schema = 'gold' AND table_name LIKE 'features%'
  AND (comment IS NULL OR comment = '')
GROUP BY table_name;
-- vazio. A tarefa auditoria_de_metadado continua verde.
```

---

## Se der errado ao vivo

| Sintoma | Causa | Correção em um prompt |
|---|---|---|
| `UNRESOLVED_COLUMN gerou_pedido` | A silver antiga comparava o resultado da visita com `'Pedido'`, e o ERP grava `'Pedido realizado'` | Rode a silver de novo: a correção já está em `04-crm-e-financeiro.sql` |
| A tarefa demora mais de 5 minutos | Os `ALTER TABLE … COMMENT` são um statement cada | Normal. São ~40 colunas × 2 tabelas |
| `recencia_dias` negativa | Faltou o filtro `data < referencia` em alguma fonte | *"O filtro tem que estar na primeira linha de cada fonte, não no fim"* |
| Taxa de positivos fora da faixa | A janela do rótulo mudou | Ajuste `JANELA_ROTULO_DIAS`, não o modelo |
| `Decimal is not JSON serializable` (na tarefa seguinte) | Faltou `CAST(... AS DOUBLE)` numa soma | Some `.cast("double")` em toda agregação de receita/margem |

**Tempo medido:** ~6 minutos de execução (o grosso são os `COMMENT`).

---

## O que fica de pé

| Objeto | O quê |
|---|---|
| `gold.features_treino` | 2.815 clientes × 22 features + rótulo, corte 2026-08-01 |
| `gold.features_cliente` | 2.816 clientes × 22 features, corte 2026-08-31 |
| Job | `rotaperfume_pipeline` com 13 tarefas |
