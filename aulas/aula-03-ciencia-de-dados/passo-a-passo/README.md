# Passo a passo da noite 3 — para seguir ao vivo

Um arquivo por prompt, curto, com o que fazer e onde clicar. Deixe esta pasta
aberta numa aba ao lado do Claude Code.

| Ordem | Arquivo | Entrega | Slides |
|---|---|---|---|
| 1º | [`01-features.md`](01-features.md) | as features dos 3.000 clientes | 16–22 |
| 2º | [`02-modelo.md`](02-modelo.md) | o modelo no catálogo e a nota de cada cliente | 23–37 |
| 3º | [`03-fila.md`](03-fila.md) | os 200 da semana, com motivo | 38–45 |

O texto completo de cada prompt, com o que falar e as armadilhas, está em
[`../prd/`](../prd). Aqui é só a sequência.

---

## Antes de começar (faça de manhã, não ao vivo)

- [ ] **Escolha o profile** e use o MESMO a noite inteira:
      `databricks auth profiles`
- [ ] **Limpe a noite 3**, se você já ensaiou. Um comando, e ele confere
      sozinho que não sobrou nada:
      `bash ../prd/99-limpar-aula-03.sh <perfil> --apagar`
- [ ] **Confira que a noite 2 está de pé** — é de onde tudo parte:

```bash
databricks experimental aitools tools query \
  "SELECT COUNT(*) AS linhas, ROUND(SUM(receita), 2) AS receita
   FROM lakehouse_rotaperfume.gold.fato_vendas" --profile <perfil>
```

Tem que voltar **191.080** e **102.303.828,05**. Se não voltar, o problema é da
noite 2 e não adianta seguir.

- [ ] **Abra três abas no navegador**, já logado:
      1. **Catalog** → `lakehouse_rotaperfume` → `gold`
      2. **Jobs & Pipelines** → `rotaperfume_pipeline` (pode aparecer como *Workflows*)
      3. **SQL Editor**, com uma query em branco

---

## O ritmo de cada prompt

O mesmo três vezes. Se decorar isto, não precisa olhar mais nada:

1. **Mostre o problema** — uma query que não responde a pergunta
2. **Cole o prompt** no Claude Code
3. **Fale enquanto ele trabalha** — os slides do bloco existem para isso
4. **Abra o DAG** quando o deploy terminar
5. **Rode a query que prova** o número
6. **Diga o que vem no próximo** e emende

> **A regra que não muda:** nunca rode o prompt seguinte sem ter mostrado o
> número do anterior na tela. É o número que segura a atenção, não o código.

---

## Se tudo der errado ao vivo

Tenha isto pronto para colar no Claude Code:

```
O deploy falhou. Leia o erro completo, explique em uma frase o que aconteceu,
conserte e faça o deploy de novo. Não mude nada além do necessário.
```

Um segundo prompt curto ensina mais do que você consertando no braço — e é
exatamente o que o aluno vai fazer na segunda-feira dele.
