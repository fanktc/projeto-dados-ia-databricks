# Passo a passo da noite 4 — para seguir ao vivo

Um arquivo por prompt, curto, com o que fazer e onde clicar. Deixe esta pasta
aberta numa aba ao lado do Claude Code.

> ⭐ **[`QUERIES.md`](QUERIES.md) — todas as queries de conferência num lugar
> só, na ordem dos prompts.** É o plano B para qualquer tela que não carregar
> ao vivo — e nesta noite a tela é o produto, então tenha o plano B pronto.

| Ordem | Arquivo | Entrega | Slides |
|---|---|---|---|
| 1º | [`01-genie.md`](01-genie.md) | o Genie da direção e a tabela de retorno | 19–24 |
| 2º | [`02-app.md`](02-app.md) | o app no ar, com a fila dos 200 | 25–33 |
| 3º | [`03-retorno.md`](03-retorno.md) | o clique que vira linha na gold | 34–39 |

O texto completo de cada prompt, com o que falar e as armadilhas, está em
[`../prd/`](../prd). Aqui é só a sequência.

---

## Antes de começar (faça de manhã, não ao vivo)

- [ ] **Escolha o profile** e use o MESMO a noite inteira:
      `databricks auth profiles`

- [ ] **Ligue o SQL warehouse.** O typegen do app depende dele, e ele demora
      para acordar:
      `databricks warehouses start 666be37e3fededf2 --profile <perfil>`

- [ ] **Zere os retornos** — é o mais comum entre um ensaio e outro. A fila
      dos 200 continua a mesma; some só o que foi clicado no app:
      `bash ../prd/99-limpar-retornos.sh <perfil> --apagar`

- [ ] **Limpe a noite 4 inteira** (app, Genie e tabela), se quiser refazer os
      três prompts do zero:
      `bash ../prd/99-limpar-aula-04.sh <perfil> --apagar`

- [ ] **Confira que a noite 3 está de pé** — é de onde tudo parte:

```bash
databricks experimental aitools tools query \
  "SELECT COUNT(*) AS contatos, COUNT(DISTINCT vendedor) AS vendedores,
          ROUND(SUM(score * ticket_medio), 2) AS receita_esperada
   FROM lakehouse_rotaperfume.gold.fila_semanal" --profile <perfil>
```

Tem que voltar **200 · 35 · 582799,50**. Se não voltar, o problema é da noite 3
e não adianta seguir.

- [ ] **Confira que `node` está instalado** — o app é Node/TypeScript:
      `node --version` (18 ou mais)

- [ ] **Confira que não há app no workspace:** `databricks apps list --profile <perfil>`
      tem que voltar vazio. Ele nasce hoje

- [ ] **Abra quatro abas no navegador**, já logado:
      1. **SQL Editor**, com o `QUERIES.md` ao lado
      2. **Genie** → `Rota do Perfume · Comercial` (o da noite 2)
      3. **Jobs & Pipelines** → `rotaperfume_pipeline`
      4. **Compute → Apps** (a lista vazia, para ver o app nascer)

---

## O ritmo da noite

Esta noite tem uma diferença das outras três: **o deploy do prompt 2 leva
quase quatro minutos**. Não é travamento — é o compute do app sendo criado.

| Momento | Duração medida | O que fazer enquanto |
|---|---|---|
| `bundle deploy` do prompt 1 | ~20s | Nada, é rápido |
| `apps init` | ~60s | Explique o que é AppKit |
| **1º `apps deploy`** | **3m44s** | Os slides 29–33: o app como usuário do UC, permissões, os tipos vindo do catálogo |
| Redeploy do prompt 3 | ~1m04s | O desenho do ciclo no quadro |

---

## Se travar no meio da aula

O app é o único artefato da imersão que pode falhar por motivo de front-end, e
front-end não é o assunto. **Regra:** se quebrar na tela, vá para o SQL. O
`QUERIES.md` responde tudo o que o app responderia.

Se o `apps deploy` falhar com `Unexpectedly failed to update app's compute
size`, **rode de novo** — é transitório no Free Edition, e resolveu na segunda
tentativa quando foi medido.
