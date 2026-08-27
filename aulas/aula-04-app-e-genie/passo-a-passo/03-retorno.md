# 3º · O retorno — o ciclo se fecha

**Entrega:** os quatro botões, a aba *Acompanhamento* e a primeira linha
gravada ao vivo. **Deploy:** `apps deploy` (~1m). **Slides:** 34–39.

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
- A tela não se atualiza sozinha: `useAnalyticsQuery` não tem `refetch`

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
| Grava mas a tela não muda | O contador de recarga não entrou nas duas queries |
| `registrado_por` sempre igual | Local não tem OAuth. No app publicado vem o e-mail real |
| Gráfico vazio no acompanhamento | É o estado certo enquanto ninguém registrou |
