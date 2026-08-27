# Todas as queries da noite 4, na ordem

Deixe este arquivo aberto numa aba do SQL Editor antes de começar. **Nesta
noite a tela é o produto** — e se a tela não carregar ao vivo, é daqui que sai
o mesmo número.

Todos os valores abaixo foram medidos no workspace em 27/08, com o dataset de
`seed 42`.

---

## Antes de começar · a noite 3 está de pé?

```sql
SELECT COUNT(*)                            AS contatos,          -- 200
       COUNT(DISTINCT vendedor)            AS vendedores,        -- 35
       ROUND(SUM(score * ticket_medio), 2) AS receita_esperada   -- 582799.50
FROM   lakehouse_rotaperfume.gold.fila_semanal;
```

Se não voltar isso, pare: o problema é da noite 3.

---

## Prompt 1 · O Genie da direção

**A tabela que ainda não existe (rode ANTES do prompt):**

```sql
SHOW TABLES IN lakehouse_rotaperfume.gold;
```

**Depois do prompt — a tabela existe, vazia e com metadado:**

```sql
DESCRIBE TABLE EXTENDED lakehouse_rotaperfume.gold.retorno_ligacao;

SELECT COUNT(*) AS linhas FROM lakehouse_rotaperfume.gold.retorno_ligacao;  -- 0

-- tem que voltar VAZIO
SELECT column_name
FROM   lakehouse_rotaperfume.information_schema.columns
WHERE  table_schema = 'gold' AND table_name = 'retorno_ligacao'
  AND  (comment IS NULL OR comment = '');
```

**O número que o Genie tem que acertar:**

```sql
SELECT ROUND(SUM(score * ticket_medio), 2) AS receita_esperada
FROM   lakehouse_rotaperfume.gold.fila_semanal;
-- 582799.50
```

**A métrica que ele tem que citar — e a que ele NÃO pode citar:**

```sql
SELECT versao,
       acertos_top200,                          -- 86
       ROUND(lift_top200, 2) AS ganho,          -- 4.25
       ROUND(taxa_base, 4)   AS base,           -- 0.1012
       ROUND(auc, 4)         AS auc             -- 0.8817  ← esta NÃO vai para a reunião
FROM   lakehouse_rotaperfume.gold.modelo_metricas
ORDER  BY versao DESC LIMIT 1;
```

---

## Prompt 2 · O app

**A fila como o diretor a receberia hoje — por e-mail:**

```sql
SELECT vendedor, ordem, razao_social, ROUND(score, 2) AS nota, motivo, sugestao
FROM   lakehouse_rotaperfume.gold.fila_semanal
ORDER  BY score DESC;
```

**Os quatro cartões do app, um por linha de SQL:**

```sql
-- contatos e vendedores          200 · 35
SELECT COUNT(*), COUNT(DISTINCT vendedor) FROM lakehouse_rotaperfume.gold.fila_semanal;

-- receita esperada               R$ 582.799,50
SELECT ROUND(SUM(score * ticket_medio), 2) FROM lakehouse_rotaperfume.gold.fila_semanal;

-- conversão prevista             43% (86 de 200) contra 10,1% às cegas
SELECT acertos_top200, ROUND(acertos_top200 / 200.0 * 100, 0) AS pct_previsto,
       ROUND(taxa_base * 100, 1) AS pct_as_cegas
FROM   lakehouse_rotaperfume.gold.modelo_metricas ORDER BY versao DESC LIMIT 1;

-- já trabalhados                 0
SELECT COUNT(*) FROM lakehouse_rotaperfume.gold.retorno_ligacao;
```

**O filtro por vendedor — quem tem mais contatos:**

```sql
SELECT   vendedor, COUNT(*) AS contatos
FROM     lakehouse_rotaperfume.gold.fila_semanal
GROUP BY vendedor
ORDER BY contatos DESC;
-- Débora Souza 12 · Henrique Oliveira 10 · Sabrina Pereira 10
```

**O primeiro da fila, que é quem você vai usar no prompt 3:**

```sql
SELECT cliente_id, razao_social, cidade, uf, ROUND(score, 4) AS score, motivo
FROM   lakehouse_rotaperfume.gold.fila_semanal
ORDER  BY score DESC LIMIT 1;
-- 2137 · Farmacia Serena Ltda Me · Goiânia/GO · 0.9740
```

**As permissões do app (troque `<sp>` pelo service principal):**

```bash
databricks apps get rotaperfume-direcao --profile <perfil> -o json | \
  python3 -c "import json,sys; print(json.load(sys.stdin)['service_principal_client_id'])"
```

```sql
GRANT USE CATALOG ON CATALOG lakehouse_rotaperfume TO `<sp>`;
GRANT USE SCHEMA  ON SCHEMA  lakehouse_rotaperfume.gold TO `<sp>`;
GRANT SELECT      ON SCHEMA  lakehouse_rotaperfume.gold TO `<sp>`;
```

**Conferir o que o app pode fazer:**

```sql
SHOW GRANTS `<sp>` ON SCHEMA lakehouse_rotaperfume.gold;
```

---

## Prompt 3 · O retorno

**A permissão de escrita — em TABLE, não em SCHEMA:**

```sql
GRANT MODIFY ON TABLE lakehouse_rotaperfume.gold.retorno_ligacao TO `<sp>`;
```

**O momento da noite — depois de clicar em *Vendeu* no app:**

```sql
SELECT cliente_id, vendedor, status, comentario, registrado_por, registrado_em
FROM   lakehouse_rotaperfume.gold.retorno_ligacao;
```

**A conversão real ao lado da prevista:**

```sql
SELECT COUNT(*)                              AS ligacoes,
       COUNT_IF(status = 'vendeu')           AS vendeu,
       ROUND(100.0 * COUNT_IF(status = 'vendeu') / NULLIF(COUNT(*), 0), 1) AS pct_real,
       43.0                                  AS pct_previsto
FROM   lakehouse_rotaperfume.gold.retorno_ligacao;
```

**O desfecho por vendedor — o que a aba Acompanhamento mostra:**

```sql
SELECT   f.vendedor,
         COUNT(*)                                 AS na_fila,
         COUNT(r.cliente_id)                      AS trabalhados,
         COUNT_IF(r.status = 'vendeu')            AS vendeu
FROM     lakehouse_rotaperfume.gold.fila_semanal f
LEFT JOIN lakehouse_rotaperfume.gold.retorno_ligacao r ON r.cliente_id = f.cliente_id
GROUP BY f.vendedor
ORDER BY trabalhados DESC, na_fila DESC;
```

**Limpar, para ensaiar de novo:**

```sql
DELETE FROM lakehouse_rotaperfume.gold.retorno_ligacao;
```

---

## O fecho · o arco das quatro noites numa query só

```sql
SELECT 'noite 1 · o dado'      AS etapa, COUNT(*) AS numero,
       'linhas na bronze de pedidos'        AS o_que_e
FROM   lakehouse_rotaperfume.bronze.pedidos
UNION ALL
SELECT 'noite 2 · o pipeline', COUNT(*), 'linhas em gold.fato_vendas'
FROM   lakehouse_rotaperfume.gold.fato_vendas
UNION ALL
SELECT 'noite 3 · a decisão', COUNT(*), 'contatos na fila da semana'
FROM   lakehouse_rotaperfume.gold.fila_semanal
UNION ALL
SELECT 'noite 4 · o retorno', COUNT(*), 'ligações que o time registrou'
FROM   lakehouse_rotaperfume.gold.retorno_ligacao;
```

> **Rode esta no fecho da noite.** As quatro linhas contam a imersão inteira, e
> a última só tem número porque alguém clicou num botão hoje.
