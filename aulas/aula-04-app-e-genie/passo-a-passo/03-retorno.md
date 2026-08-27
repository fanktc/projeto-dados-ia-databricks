# 3º · O retorno — o ciclo se fecha

**Entrega:** os quatro botões, a aba *Acompanhamento* e a primeira linha
gravada ao vivo. **Deploy:** `apps deploy` (~1m). **Slides:** 34–41.

---

## Antes de colar o prompt

**1. A pergunta que o projeto ainda não responde:**

```sql
SELECT COUNT(*) FROM lakehouse_rotaperfume.gold.retorno_ligacao;   -- 0
```

> *"O modelo diz que 86 dos 200 vão comprar. Alguém sabe se ele acertou?"*

**2. Desenhe o ciclo** (slide 35):

```
   pipeline  →  score  →  fila  →  ligação  →  ???
                  ↑                              │
                  └──────────────────────────────┘
```

> *"O que o vendedor responde hoje é o rótulo de treino da semana que vem."*

**3. A pergunta de permissão:** *"Que permissão o app precisa para escrever?"*
A resposta certa é `MODIFY` **em uma tabela só**.

---

## O prompt

Copie de [`../prd/prompt-03-retorno.md`](../prd/prompt-03-retorno.md) → seção
**O prompt**.

---

## Enquanto ele trabalha

- Leitura e escrita não usam o mesmo caminho
- A validação está no servidor, não no botão — botão é interface, `enum` é
  contrato
- `x-forwarded-email` grava quem clicou
- A tela não se atualiza sozinha: `useAnalyticsQuery` não tem `refetch`. A
  saída é desligar o cache e remontar o componente com uma `key` — não um
  parâmetro falso no SQL, que quebra a tela de quem está com o JS antigo

---

## O teste do ciclo completo — banco, app, banco

Faça isto **antes da aula**, com o SQL Editor e o app abertos lado a lado. São
cinco passos e provam a coisa inteira: o dado sai do pipeline, aparece na tela,
volta pelo clique e é lido de novo.

### 1 · O estado inicial, no banco

```sql
-- quantos retornos existem hoje (no começo da aula: 0)
SELECT COUNT(*) AS retornos FROM lakehouse_rotaperfume.gold.retorno_ligacao;

-- e a tabela inteira, para ver que está mesmo vazia
SELECT * FROM lakehouse_rotaperfume.gold.retorno_ligacao;
```

### 2 · Escolha quem você vai "ligar" — e guarde o id

```sql
SELECT   cliente_id, razao_social, cidade, uf, vendedor,
         ROUND(score, 4) AS score, ordem, motivo
FROM     lakehouse_rotaperfume.gold.fila_semanal
ORDER BY score DESC
LIMIT    3;
```

O primeiro é **2137 · Farmacia Serena Ltda Me · Goiânia/GO · Bruno Souza**,
com score **0,974**. É o que aparece no topo do app.

### 3 · O mesmo cliente, do ponto de vista do app

```sql
-- é exatamente esta linha que a tela mostra, com o retorno ainda em NULL
SELECT   f.razao_social, f.vendedor, ROUND(f.score,2) AS chance,
         f.motivo, f.sugestao,
         r.status AS retorno, r.registrado_por
FROM     lakehouse_rotaperfume.gold.fila_semanal f
LEFT JOIN lakehouse_rotaperfume.gold.retorno_ligacao r ON r.cliente_id = f.cliente_id
WHERE    f.cliente_id = 2137;
```

`retorno` e `registrado_por` voltam **NULL**. Ninguém ligou ainda.

### 4 · Agora vá para o app e faça o apontamento

1. Abra a aba **A semana**
2. Primeira linha, campo de comentário: *"pediu para ligar quinta"*
3. Clique em **Vendeu**
4. O cartão **Já trabalhados** sobe na hora, e a linha troca os botões por um
   selo verde com o comentário embaixo

### 5 · Volte ao banco — e é aqui que a sala entende

```sql
-- a linha que não existia há trinta segundos
SELECT cliente_id, vendedor, status, comentario, registrado_por, registrado_em
FROM   lakehouse_rotaperfume.gold.retorno_ligacao
ORDER  BY registrado_em DESC;
```

**Repare em `registrado_por`: é o seu e-mail.** O app não gravou como "sistema"
nem como um usuário genérico — ele sabe quem clicou, porque o login é o do
Databricks.

E a mesma query do passo 3, de novo:

```sql
SELECT   f.razao_social, r.status AS retorno, r.comentario, r.registrado_por
FROM     lakehouse_rotaperfume.gold.fila_semanal f
LEFT JOIN lakehouse_rotaperfume.gold.retorno_ligacao r ON r.cliente_id = f.cliente_id
WHERE    f.cliente_id = 2137;
```

O que era NULL agora tem valor. **O ciclo fechou.**

### 6 · O acompanhamento, no banco e na tela

```sql
SELECT   f.vendedor,
         COUNT(*)                       AS na_fila,
         COUNT(r.cliente_id)            AS trabalhados,
         COUNT_IF(r.status = 'vendeu')  AS vendeu
FROM     lakehouse_rotaperfume.gold.fila_semanal f
LEFT JOIN lakehouse_rotaperfume.gold.retorno_ligacao r ON r.cliente_id = f.cliente_id
GROUP BY f.vendedor
HAVING   COUNT(r.cliente_id) > 0
ORDER BY trabalhados DESC;
```

Abra a aba **Acompanhamento**: os mesmos números, com o vendedor que você
acabou de trabalhar aparecendo na barra. Se a tela mostrar número diferente do
SQL, clique em **Atualizar**.

### 7 · E o Genie responde sobre o que acabou de acontecer

No space **Rota do Perfume · Direção**:

```
Quantas ligações já foram registradas e quantas viraram pedido?
```

Ele responde o número novo. **Nenhuma linha do Genie mudou** — mudou o dado
embaixo dele.

### Para repetir o teste

```bash
bash ../prd/99-limpar-retornos.sh <perfil> --apagar
```

Zera só os retornos; a fila dos 200 e o modelo continuam intactos.

---

## O momento da noite — faça exatamente nesta ordem

1. No app, primeiro cliente: **Farmácia Serena**, Goiânia, chance **97%**
2. Escreva no comentário: *"pediu para ligar quinta"*
3. Clique em **Vendeu**
4. O cartão *Já trabalhados* vai de **0** para **1**
5. Vá para o SQL Editor e rode, com a sala olhando:

```sql
SELECT cliente_id, vendedor, status, comentario, registrado_por, registrado_em
FROM   lakehouse_rotaperfume.gold.retorno_ligacao;
```

**Com o seu e-mail em `registrado_por`.**

6. Volte para a aba **Perguntar** e pergunte:
   *"Quantas ligações já foram registradas e quantas viraram pedido?"*
   Ele responde **1 e 1** — e vinte minutos atrás respondia zero.
   **Nenhuma linha do Genie mudou.**

---

## Conferir também

O contrato recusa o que não é válido:

```bash
curl -X POST <URL>/api/retorno -H "Content-Type: application/json" \
  -d '{"cliente_id":2137,"vendedor":"Bruno Souza","status":"talvez","referencia":"2026-08-31"}'
# 400, com a lista dos quatro valores aceitos. Nada chega ao warehouse.
```

---

## Se der errado

| Sintoma | Saída |
|---|---|
| `PERMISSION_DENIED` ao gravar | `GRANT MODIFY ON TABLE` — em TABLE, não em SCHEMA |
| Grava mas a tela não muda | Cache ligado, ou a `key` do componente não mudou |
| `UNBOUND_SQL_PARAMETER` | JS antigo no navegador pedindo uma query nova. `Ctrl+Shift+R` |
| `registrado_por` sempre igual | Local não tem OAuth. No app publicado vem o e-mail real |
| Gráfico vazio no acompanhamento | É o estado certo enquanto ninguém registrou |
