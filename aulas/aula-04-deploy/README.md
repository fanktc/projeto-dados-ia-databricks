# 🚀 Dia 4: Deploy | Imersão Jornada de Dados

> **Status:** o job de ingestão **já está no ar**. Monitoramento e custo entram
> ao vivo na quinta, 27/08.

**Promessa da noite:** colocar de pé e conseguir defender internamente.

## 📦 O bundle

[`perfumesarabe/`](perfumesarabe) é um Declarative Automation Bundle (DABs).
Ele empacota o código, cria o job no workspace e agenda a execução.

```bash
cd aulas/aula-04-deploy/perfumesarabe
databricks bundle validate --target dev --profile SEU-PERFIL
databricks bundle deploy   --target dev --profile SEU-PERFIL
databricks bundle run rota_perfume_bronze --target dev --profile SEU-PERFIL
```

## 🔁 O que o job faz

Duas tarefas em serverless, e a ordem importa:

```
bronze  ──→  verificacao
(ingere)     (confere, e falha se o número mudou)
```

| Tarefa | O que roda |
|---|---|
| `bronze` | Lê os 10 CSVs do volume e grava Delta. Falha se a volumetria divergir |
| `verificacao` | 9 checagens: receita, ticket, e a sujeira que a bronze deve preservar |

**O job falha de propósito** quando um número foge do esperado. É melhor o
alerta tocar do que o dashboard mentir.

Última execução: 10 tabelas, 313.551 linhas, 9 verificações passando.

## 🧪 Testes

```bash
cd aulas/aula-04-deploy/perfumesarabe && uv sync --dev && uv run pytest
```

Cinco testes: contrato dos módulos (sem Databricks) e volumetria da bronze
(via Databricks Connect, com fallback para serverless).

## ⚙️ Como o mesmo código roda em dois lugares

Catálogo e schema vêm das variáveis do bundle, não do código:

```yaml
targets:
  dev:   { variables: { catalog: rota_perfume, schema: bronze } }
  prod:  { variables: { catalog: rota_perfume, schema: bronze } }
```

Em `dev` o agendamento nasce **pausado**. Em `prod` ele fica ativo — atenção à
cota da Free Edition antes de subir.

## ➡️ O que entra ao vivo

- Monitoramento: saber que quebrou antes do gestor saber
- Custo: quanto o projeto consome, e como não estourar
- Como defender o projeto internamente
- Portfólio: o repositório como prova de trabalho
