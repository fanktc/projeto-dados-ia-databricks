# Prompt 1 · Features

**Slides 16 a 22 · ~17 minutos · 1º deploy da noite**

## O que este prompt faz

Transforma o fato de vendas, que tem uma linha por **item**, em uma tabela com
uma linha por **cliente** e 20 colunas de comportamento. Grava duas: uma para
treinar (corte 01/08, com a resposta) e uma para pontuar (corte 31/08, sem).

No fim existe `gold.features_cliente` — e é dela que o modelo vai comer.

---

## 1 · Antes de colar (2 min)

**SQL Editor.** Cole e rode:

```sql
SELECT cliente_id, COUNT(*) AS linhas_no_fato
FROM lakehouse_rotaperfume.gold.fato_vendas
GROUP BY cliente_id ORDER BY 2 DESC LIMIT 5;
```

> *"Modelo não come tabela fato. Ele come uma linha por coisa que você quer
> prever, com todas as colunas na mesma linha."*

Depois rode a query dos dois clientes com a mesma recência — está em
[`../prd/prompt-01-features.md`](../prd/prompt-01-features.md), item 3 do
"O que mostrar antes". **É o argumento da noite inteira em uma tela.**

---

## 2 · Colar o prompt

Abra [`../prd/prompt-01-features.md`](../prd/prompt-01-features.md), copie o
bloco **## O prompt** inteiro e cole no Claude Code.

Troque `<perfil>` pelo seu, se aparecer.

---

## 3 · Enquanto ele trabalha (fale, não espere)

Slides **17 a 22**, nesta ordem:

- **17** — o que é feature engineering: agregar, relativizar, sinalizar
- **19** — RFM, o básico que funciona
- **20** — os dois clientes com a mesma recência
- **21** — `atraso_relativo`, a feature que ordena a fila
- **22** — os quatro grupos, e a query que você vai rodar daqui a pouco

---

## 4 · Quando terminar: onde clicar

- [ ] **Catalog** (menu da esquerda) → `lakehouse_rotaperfume` → `gold`
      → as tabelas `features_treino` e `features_cliente` apareceram
- [ ] Clique em `features_cliente` → aba **Sample data**
      → uma linha por cliente, 20 colunas
- [ ] Aba **Details** → o COMMENT em português está lá
- [ ] **Jobs & Pipelines** → `rotaperfume_pipeline` → a tarefa `ml_features`
      entrou no fim do DAG

---

## 5 · A query que prova

```sql
-- 1. os dois cortes, declarados na própria tabela
SELECT '_treino' AS tabela, COUNT(*) AS clientes, MIN(_referencia) AS corte
FROM lakehouse_rotaperfume.gold.features_treino
UNION ALL
SELECT '_cliente', COUNT(*), MIN(_referencia)
FROM lakehouse_rotaperfume.gold.features_cliente;

-- 2. O NÚMERO DA NOITE: a taxa base
SELECT COUNT(*)                             AS clientes,
       SUM(comprou_em_7d)                   AS compraram,
       ROUND(100 * AVG(comprou_em_7d), 1)   AS taxa_base_pct
FROM lakehouse_rotaperfume.gold.features_treino;
```

**Tem que dar 2.809 clientes e 10,11%.**

> **Escreva "20 de 200" no quadro.** É a taxa base: de cada 200 ligações às
> cegas, 20 viram pedido. Todo o prompt 2 é a tentativa de superar isso.

---

## 6 · Emenda para o próximo

> *"Agora eu tenho 3.000 clientes descritos em 20 colunas. Só que descrever
> não é ordenar. Quem decide quais 200?"*

---

## Se der errado

| O que aparece | O que fazer |
|---|---|
| `Object of type Decimal is not JSON serializable` | só aparece no prompt 2 — peça `cast("double")` nas features numéricas |
| A auditoria de metadado quebrou o job | **é o teste da noite 2 funcionando.** Mostre, peça o `COMMENT` e rode de novo |
| Alguma feature veio de `dim_cliente` | é vazamento — ela agrega a base inteira, sem corte. **Mostre ao vivo:** é o slide 29 (vazamento) acontecendo antes da hora |
| A recência mínima veio negativa | um filtro `< referencia` escapou. Mesmo caso acima, e vale ouro |
