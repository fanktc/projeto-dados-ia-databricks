# 2º · O app — a fila dos 200 na tela

**Entrega:** o app no ar, com os quatro números e a fila filtrável.
**Deploy:** `apps deploy` — **3m44s na primeira vez**. **Slides:** 25–33.

---

## Antes de colar o prompt

**1. Mostre a query da fila no SQL Editor** e diga a frase:

> *"Está certíssimo. Agora imagine mandar isso para o diretor toda segunda de
> manhã."*

**2. A tabela das três portas** (slide 27): dashboard acompanha, Genie
responde, **app registra**. A diferença é a direção do dado.

**3. Ligue o warehouse ao vivo** — e avise que já já explica por quê:

```bash
databricks warehouses start 666be37e3fededf2 --profile <perfil>
```

**4. Pegue o id do Genie do prompt 1** (o prompt precisa dele):

```bash
databricks genie list-spaces --profile <perfil>
```

---

## O prompt

Copie de [`../prd/prompt-02-app.md`](../prd/prompt-02-app.md) → seção
**O prompt**. Substitua `<o id do space>` pelo id que você acabou de ler.

---

## Enquanto ele trabalha — e são quase 4 minutos

Esta é a janela mais longa da imersão. Use nesta ordem:

1. **O app é um usuário do Unity Catalog** (slide 29). `CAN_USE` no warehouse
   dá acesso ao compute, não ao dado. A tela do erro é a pior: carrega, não
   quebra, e mostra vazio
2. **Os tipos vêm do catálogo** (slide 31). Mostre o `analytics.d.ts` gerado —
   o `COMMENT` da noite 2 virou documentação no editor
3. **Nenhuma query dentro do React** (slide 32). SQL em `.sql`, interface em
   `.tsx`
4. **Por que quatro minutos** (slide 33). O segundo deploy leva um

---

## Conferir, na ordem

```bash
databricks apps get rotaperfume-direcao --profile <perfil> -o json | \
  python3 -c "import json,sys; d=json.load(sys.stdin); print(d['url'], d['app_status']['state'])"
```

Abra a URL e confira **os quatro cartões contra o SQL**, lado a lado:

| Cartão | Valor | Query |
|---|---|---|
| Contatos | **200** · 35 vendedores | `COUNT(*)`, `COUNT(DISTINCT vendedor)` |
| Receita esperada | **R$ 582.799,50** | `SUM(score * ticket_medio)` |
| Conversão prevista | **43%** vs 10,1% | `acertos_top200 / 200` |
| Já trabalhados | **0** | `COUNT(*)` do retorno |

Depois:

- Filtre por **Débora Souza** → 12 contatos, o maior da fila
- Abra **Perguntar** e faça uma pergunta com o SQL à vista

---

## Se der errado

| Sintoma | Saída |
|---|---|
| Tela vazia, sem erro | Faltam os `GRANT` para o service principal |
| typegen `OFFLINE` / `{}` como tipo | Warehouse parado. Ligue e rode de novo |
| `dev: no such target` | O target do app é `default` |
| App parado, sem URL | Rodou `bundle deploy`. Use `apps deploy` |
| `failed to update app's compute size` | Transitório. Rode de novo |
