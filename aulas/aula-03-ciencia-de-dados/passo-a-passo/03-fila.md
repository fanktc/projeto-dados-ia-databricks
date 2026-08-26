# Prompt 3 · A fila e o agente

**Slides 38 a 45 · ~18 minutos · 3º deploy da noite**

## O que este prompt faz

Pega os 200 maiores scores da base inteira, cruza com a carteira de cada
vendedor e escreve a lista da semana **em português**: quem ligar, por quê e o
que oferecer. Cria também as quatro funções que o agente consulta.

No fim existe `gold.fila_semanal` — e ela é a resposta literal ao que o diretor
perguntou no slide 2.

---

## 1 · Antes de colar (3 min)

**SQL Editor.** Mostre o score cru, como ele sai do modelo:

```sql
SELECT cliente_id, ROUND(score, 4) AS score, faixa
FROM lakehouse_rotaperfume.gold.score_propensao
ORDER BY score DESC LIMIT 5;
```

> *"Está certíssimo e é inútil. Entregue isso para o vendedor e ele volta a
> ligar pela intuição na segunda-feira."*

**Depois faça a pergunta que decide o desenho da tabela:**

> *"São 200 ligações e 42 vendedores. Dou 5 para cada um, ou dou os 200
> melhores da base inteira?"*

A sala responde "5 para cada, é mais justo". E aí: *"justo com quem? Se a
carteira do João está quente e a do Pedro está fria, a cota igual obriga o
João a deixar cliente quente na mesa."*

---

## 2 · Colar o prompt

Bloco **## O prompt** de
[`../prd/prompt-03-fila-e-agente.md`](../prd/prompt-03-fila-e-agente.md).

---

## 3 · Enquanto ele trabalha

Slides **39 a 42**:

- **39** — batch ou tempo real *(pule se estiver atrasado)*
- **40** — o último metro, onde os projetos de ML morrem
- **41** — as quatro ferramentas: ele não inventa, ele consulta
- **42** — a resposta para o diretor

---

## 4 · Quando terminar: onde clicar

- [ ] **Catalog** → `gold` → `fila_semanal` → **Sample data**
- [ ] Ainda em `gold`, role até **Functions**: as quatro estão lá,
      cada uma com o COMMENT que o agente lê
- [ ] **Jobs & Pipelines** → o DAG fechou com `ml_fila`. **15 tarefas.**
      Abra a tela inteira e deixe a sala olhar por três segundos
- [ ] **Genie** (menu da esquerda) → o espaço comercial → confirme que
      `fila_semanal` está entre as tabelas

---

## 5 · A query que prova

```sql
-- 1. A LISTA. É o slide 42 saindo do banco.
SELECT vendedor, ordem, razao_social, ROUND(score, 2) AS score, motivo
FROM lakehouse_rotaperfume.gold.fila_semanal
WHERE vendedor = (SELECT vendedor FROM lakehouse_rotaperfume.gold.fila_semanal
                  GROUP BY vendedor ORDER BY COUNT(*) DESC LIMIT 1)
ORDER BY ordem;

-- 2. A conta fecha, e a distribuição conta uma história
SELECT COUNT(DISTINCT vendedor) AS vendedores, COUNT(*) AS ligacoes
FROM lakehouse_rotaperfume.gold.fila_semanal;

-- 3. A ferramenta, chamada como o agente chamaria
SELECT * FROM lakehouse_rotaperfume.gold.priorizar_carteira('<nome do vendedor>', 5);
```

**Leia a primeira linha da lista em voz alta e pare.** É o fim do argumento.

---

## 6 · O agente, no Genie (5 min)

Abra o Genie e pergunte **com as palavras do vendedor**:

- [ ] *"Quem eu ligo essa semana?"*
- [ ] *"Por que esse cliente está no topo da minha lista?"*

**Mostre o SQL que o Genie gerou.** É a diferença entre agente e chute: a
resposta tem query embaixo.

---

## 7 · O fechamento

Slides **43 a 45**: o antes e o depois, o arco das três noites, a frase.

> *"Dashboard descreve o passado. Modelo prevê o futuro. Agente diz o que fazer
> na segunda de manhã. E vocês construíram junto — não assistiram."*

**Só então abra o carrinho.** A prova é o argumento de venda.

---

## Se der errado

| O que aparece | O que fazer |
|---|---|
| `CREATE FUNCTION` falha com coluna ambígua | parâmetro com nome igual ao de uma coluna — peça o prefixo `p_` |
| `RETURNS TABLE` recusado no workspace | plano B: as quatro viram **views** `gold.ferramenta_*`. O argumento é o mesmo |
| A fila veio com menos de 200 linhas | cliente sem carteira vigente, ou vendedor desligado. **É dado real** — mostre e explique |
| `motivo` com `NULL` no meio | faltou o `ELSE` no `CASE WHEN`. O teste 2 pegou: é o teste funcionando |
| O Genie inventou um número | a instrução não entrou no espaço. Mostre o antes e o depois — vale mais que dez slides sobre alucinação |
