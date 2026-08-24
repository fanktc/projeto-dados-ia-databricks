# 🚀 Dia 4: Deploy | Imersão Jornada de Dados

> **Status:** o job de ingestão **já está no ar e rodando**. Monitoramento,
> custo e a conversa de defesa interna entram ao vivo na quinta, 27/08.

Três noites de construção. Se tudo morrer no seu notebook, não valeu nada.

> **Promessa da noite:** colocar de pé e conseguir defender internamente.
> **Pergunta da noite:** *"Como eu provo que isso presta e não vai cair?"*

---

## 🧠 O que muda quando vai para produção

No notebook você roda e olha o resultado. Em produção ninguém está olhando —
então o código precisa saber quando ele mesmo está errado.

```
  NOTEBOOK                      PRODUÇÃO

  você roda                     roda sozinho, agendado
  você vê o erro                o erro precisa gritar
  caminho na mão                catálogo vem de variável
  "funcionou aqui"              teste diz se funcionou
```

---

## 📦 O bundle

[`perfumesarabe/`](perfumesarabe) é um **Declarative Automation Bundle** (DABs):
empacota o código, cria o job no workspace e agenda a execução. É infraestrutura
como código — o que está no Git é o que está no ar.

```bash
cd aulas/aula-04-deploy/perfumesarabe

databricks bundle validate --target dev --profile SEU-PERFIL
databricks bundle deploy   --target dev --profile SEU-PERFIL
databricks bundle run rota_perfume_bronze --target dev --profile SEU-PERFIL
```

### O que o job faz

Duas tarefas em serverless, e a ordem importa:

```
  bronze  ─────→  verificacao
  (ingere)        (confere, e falha se o número mudou)
```

| Tarefa | O que roda | Falha quando |
|---|---|---|
| `bronze` | Lê os 10 CSVs do volume e grava Delta | a volumetria diverge do esperado |
| `verificacao` | 9 checagens de negócio e de sujeira | receita, ticket ou sujeira mudaram |

**O job falha de propósito.** Queda silenciosa de ingestão é o pior cenário: o
pipeline "passa", o dashboard mostra menos venda, e alguém descobre três
semanas depois. Melhor o alerta tocar.

Última execução: **10 tabelas, 313.551 linhas, 9 verificações passando.**

---

## ⚙️ O mesmo código em dev e prod

Catálogo e schema vêm das variáveis do bundle, nunca do código:

```yaml
targets:
  dev:
    mode: development      # recursos ganham prefixo [dev seu_nome]
    variables: { catalog: rota_perfume, schema: bronze }
  prod:
    mode: production
    variables: { catalog: rota_perfume, schema: bronze }
```

Em `dev` o agendamento nasce **pausado**. Em `prod` ele fica ativo — repare na
cota da Free Edition antes de subir, porque aí ele roda todo dia.

---

## 🧪 Testes

```bash
cd aulas/aula-04-deploy/perfumesarabe
uv sync --dev
uv run pytest
```

Cinco testes, em duas categorias:

| Tipo | O que verifica | Precisa de workspace? |
|---|---|---|
| Contrato | toda tabela tem contagem esperada, caminhos batem | não |
| Dado | volumetria da bronze, tudo em texto | sim (Databricks Connect) |

---

## 📁 Onde está cada coisa

| Caminho | O que é |
|---|---|
| `perfumesarabe/databricks.yml` | O bundle: variáveis, targets, artefato |
| `perfumesarabe/resources/rota_perfume.job.yml` | O job e as duas tarefas |
| `perfumesarabe/src/perfumesarabe/ingestao.py` | Lê os CSVs, grava Delta |
| `perfumesarabe/src/perfumesarabe/verificacao.py` | As 9 checagens |
| `perfumesarabe/src/perfumesarabe/main.py` | Os entrypoints `bronze` e `verificar` |

---

## ➡️ O que entra ao vivo

- **Monitoramento** — saber que quebrou antes de o gestor saber
- **Custo** — quanto o projeto consome, e como não estourar a Free Edition
- **Defesa interna** — como apresentar isso para quem paga a conta
- **Portfólio** — o repositório como prova de trabalho, não como pasta de scripts
