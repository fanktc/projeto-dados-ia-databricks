# Prompt 3 · A fila e o agente

**Slides que acompanham:** 38 a 45 (divisor *"Os 200"*, batch ou tempo real, o
gap que mata projetos, as ferramentas do agente, a resposta para o diretor, o
antes e o depois, o arco de três noites, a frase da noite).

**Entrega:** `gold.fila_semanal` — as 200 linhas com nome, motivo em português
e o que oferecer — mais as quatro ferramentas que o agente consulta.
**Deploy nº 3 da noite.**

> Score não é decisão. `0,8412` não é uma ação. Este prompt é o último metro:
> o que separa o modelo que roda do modelo que alguém usa.

---

## O que mostrar antes

**1 · O score, cru, como ele sai do modelo**

```sql
SELECT cliente_id, ROUND(score, 4) AS score, faixa
FROM lakehouse_rotaperfume.gold.score_propensao
ORDER BY score DESC LIMIT 5;
```

> *"Está certíssimo e é inútil. Entregue isso para o vendedor e ele volta a
> ligar pela intuição na segunda-feira. Já vi acontecer com modelo de AUC 0,89
> rodando há dois anos."*

**2 · A pergunta que decide o desenho da tabela**

Faça para a sala antes de colar o prompt:

> *"São 200 ligações e 42 vendedores. Dou 5 para cada um, ou dou os 200
> melhores da base inteira?"*

A resposta quase sempre é "5 para cada, é mais justo". E aí:

> *"Justo com quem? Se a carteira do João está quente e a do Pedro está fria,
> a cota igual obriga o João a deixar cliente quente na mesa para o Pedro
> ligar para cliente frio."*

**A fila é global; a capacidade é que é por pessoa.** É por isso que a tabela
sai com `ORDER BY score DESC LIMIT 200` e não com cota por vendedor.

---

**Enquanto ele trabalha, você explica:**

- **O último metro é onde os projetos morrem.** Dado, modelo, score na
  tabela — e ninguém liga. O gargalo nunca é o algoritmo.
- **Motivo em português não é enfeite.** É o que faz o vendedor confiar
  quando o modelo acerta, e o que permite entender **por que** quando ele
  erra, em vez de simplesmente parar de usar.
- **Agente não inventa: ele consulta.** As quatro ferramentas são consultas ao
  Unity Catalog, com nome e contrato. Agente sem dado organizado por trás é
  chute com sotaque — e as três noites anteriores foram construir esse dado.
- **A carteira entra aqui.** O score é por cliente; a ligação é por vendedor.
  `silver.carteira` é quem faz a ponte, e é por isso que ela foi limpa na
  noite 2.

---

## O prompt

```
Continue o mesmo bundle. gold.score_propensao tem os 3.000 clientes com nota.

Crie src/ml/13-fila.sql — um arquivo SQL para rodar como sql_task.

1. A TABELA DA SEMANA: gold.fila_semanal

   Junte score_propensao com features_cliente, dim_cliente e silver.carteira.
   Os 200 clientes de maior score da BASE INTEIRA — ORDER BY score DESC
   LIMIT 200 — e só depois divida por vendedor, com
   ROW_NUMBER() OVER (PARTITION BY vendedor ORDER BY score DESC) para dar a
   ordem de ligação de cada um.
   Não use cota igual por vendedor: a carteira de um é mais quente que a do
   outro, e cota fixa obriga a gastar ligação com cliente frio.

   Colunas: vendedor, ordem, cliente_id, razao_social, cidade, uf, score,
   faixa, ticket_medio, e duas colunas escritas para gente ler:

   motivo — uma frase em português montada com CASE WHEN sobre as features:
     atraso_relativo > 3  -> 'Compra a cada N dias e está há M sem pedido.
                              Risco de perder para o concorrente.'
     atraso_relativo > 1.5-> 'Está N vezes mais atrasado que o ritmo dele.'
     comprou_lancamento   -> 'Comprou o lançamento no mês passado.
                              Alta chance de repetir.'
     valor_total alto     -> 'Cliente grande, R$ X no ano. Manter próximo.'
     senão                -> 'Dentro do ritmo. Contato de manutenção.'
     Use os números reais do cliente dentro da frase, com FORMAT_NUMBER.

   sugestao — a marca que ele mais comprou e parou de comprar nos últimos
     90 dias, com a observação de estoque vinda de silver.estoque.

2. AS QUATRO FERRAMENTAS, como funções SQL no Unity Catalog, cada uma com
   COMMENT em português dizendo para que serve (é o COMMENT que o agente lê):

   gold.priorizar_carteira(vendedor STRING, quantos INT)
     RETURNS TABLE — a fatia da fila_semanal daquele vendedor, em ordem
   gold.contexto_cliente(cliente_id BIGINT)
     RETURNS TABLE — histórico, ticket médio, marcas preferidas, última compra
   gold.sugerir_produtos(cliente_id BIGINT)
     RETURNS TABLE — o que ele compra e parou de comprar nos últimos 90 dias
   gold.checar_disponibilidade(sku STRING)
     RETURNS TABLE — estoque atual e flag de ruptura, de silver.estoque

3. TRÊS TESTES QUE QUEBRAM O JOB, no mesmo padrão raise_error() dentro de
   CASE WHEN que a noite 2 usa:
   - a fila tem exatamente 200 linhas
   - nenhuma linha com motivo nulo ou vazio
   - nenhum score fora do intervalo [0, 1]

4. Adicione gold.fila_semanal e gold.score_propensao ao Genie Space de
   resources/genie.genie_space.json, com a instrução:
   "Use sempre as tabelas e funções deste espaço. Nunca invente número,
    nome de cliente ou quantidade de estoque."

Tabelas, colunas e funções com COMMENT em português.

Registre a tarefa ml_fila em resources/pipeline.job.yml, depois de ml_modelo,
e faça o deploy.
```

---

## Como verificar a feature

**1 · A resposta para o diretor, na tela**

```sql
SELECT vendedor, ordem, razao_social, ROUND(score, 2) AS score, motivo
FROM lakehouse_rotaperfume.gold.fila_semanal
WHERE vendedor = (SELECT vendedor FROM lakehouse_rotaperfume.gold.fila_semanal
                  GROUP BY vendedor ORDER BY COUNT(*) DESC LIMIT 1)
ORDER BY ordem;
```

A lista de quem recebeu mais contatos, com nome e motivo. **É o slide *A resposta para o diretor* saindo do banco.** Leia a
primeira em voz alta e pare.

**2 · A conta fecha, e a distribuição conta uma história**

```sql
SELECT COUNT(DISTINCT vendedor) AS vendedores,
       COUNT(*)                 AS ligacoes
FROM lakehouse_rotaperfume.gold.fila_semanal;

-- quem recebeu muito e quem recebeu pouco
SELECT vendedor, COUNT(*) AS ligacoes, ROUND(AVG(score), 3) AS score_medio
FROM lakehouse_rotaperfume.gold.fila_semanal
GROUP BY vendedor ORDER BY ligacoes DESC;
```

**200 contatos em ~42 vendedores, de 2 a 10 ligações cada.** O vendedor do topo
não é o melhor vendedor — é o que tem a carteira mais quente. E isso é uma
conversa de negócio que só existe porque agora tem número.

**3 · A ferramenta, chamada como o agente chamaria**

```sql
SELECT * FROM lakehouse_rotaperfume.gold.priorizar_carteira('Ana Souza', 5);
```

> *"Isso não é um endpoint, não é um framework e não tem prompt nenhum. É uma
> função no catálogo, com contrato e comentário. O agente só sabe chamar."*

**4 · O Genie, que é a interface**

Abra o Genie Space e pergunte, com as palavras do vendedor:

> *"Quem eu ligo essa semana?"*

Depois peça o que só o dado responde:

> *"Por que a Perfumaria Aurora está no topo da minha lista?"*

**Mostre o SQL que o Genie gerou.** É a diferença entre agente e chute: a
resposta tem query embaixo.

---

## Se der errado

| Sintoma | Causa | Saída |
|---|---|---|
| `CREATE FUNCTION ... RETURNS TABLE` recusado | função de tabela indisponível no workspace | plano B: crie as quatro como **views** (`gold.ferramenta_*`) e mostre o Genie consultando; o argumento da aula é o mesmo |
| A fila veio com menos de 200 linhas | cliente sem vendedor na carteira, ou carteira com vendedor desligado | é uma das dez sujeiras da noite 2 — mostre, e decida na hora: excluir ou atribuir ao gerente |
| `motivo` com `NULL` no meio | faltou o `ELSE` no `CASE WHEN` | o teste 2 pegou. É o teste funcionando |
| O Genie inventou um número | a instrução não entrou no espaço | mostre o antes e o depois da instrução — vale mais que dez slides sobre alucinação |
