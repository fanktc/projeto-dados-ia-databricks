# 🧭 Imersão Jornada de Dados · Rota do Perfume

Construir a área de dados e vendas de uma distribuidora B2B **do zero, em 4 noites**.
Empresa fictícia, dado gerado com seed fixa, sujeira proposital.

> **Domínio:** distribuidora de perfumaria árabe — vende para perfumarias, farmácias,
> revendedoras e e-commerces.
> **Stack:** Databricks Free Edition (serverless), SQL, Python e Claude Code.

---

## 🗓️ As quatro noites

| Noite | Data | Tema | Pasta |
|---|---|---|---|
| **1** | seg 24/08 | Objetivo e a primeira análise | [`aulas/aula-01-databricks-sql`](aulas/aula-01-databricks-sql) · [📺 gravação](https://youtube.com/live/plG6mF-ib_w) |
| **2** | ter 25/08 | Engenharia de dados: o projeto roda sozinho | [`aulas/aula-02-engenharia-de-dados`](aulas/aula-02-engenharia-de-dados) |
| **3** | qua 26/08 | Ciência de dados e agentes | [`aulas/aula-03-ciencia-de-dados-e-agentes`](aulas/aula-03-ciencia-de-dados-e-agentes) |
| **4** | qui 27/08 | Deploy: o projeto no ar e monitorado | [`aulas/aula-04-deploy`](aulas/aula-04-deploy) |

Cada pasta é autocontida: tem o próprio README, os exemplos numerados e o que
for preciso rodar.

---

## 🚀 Comece por aqui

```bash
# 1. gerar o dataset (seed fixa: todo mundo gera exatamente o mesmo dado)
python3 material/gerar_dataset.py --saida ./dados --seed 42

# 2. autenticar no Databricks
databricks auth login --host https://SEU-WORKSPACE.cloud.databricks.com --profile meu-perfil

# 3. seguir a aula 01
cd aulas/aula-01-databricks-sql && cat README.md
```

O runner `scripts/run_sql.py` executa qualquer `.sql` deste repositório no
warehouse, uma statement por vez:

```bash
python3 scripts/run_sql.py aulas/aula-01-databricks-sql/exemplo-01-primeiro-select.sql
```

---

## 🗄️ O dataset

Gerado por `material/gerar_dataset.py`, ~14 MB, período de setembro/2024 a agosto/2026.

```
dados/
├── erp/    produtos · pedidos · itens_pedido · pagamentos · estoque
└── crm/    clientes · vendedores · carteira · oportunidades · visitas
```

| Tabela | Linhas | O que tem |
|---|---|---|
| `pedidos` | 28.729 | cliente, vendedor, data, canal, status, valor |
| `itens_pedido` | 197.724 | SKU, quantidade, preço praticado, desconto |
| `pagamentos` | 27.772 | forma, parcelas, vencimento, status |
| `produtos` | 292 | categoria, marca, nota olfativa, custo, lançamento |
| `estoque` | 8.400 | snapshot semanal por SKU, com ruptura |
| `clientes` | 3.040 | CNPJ, razão social, segmento, cidade |
| `visitas` | 37.936 | data, resultado, duração |
| `oportunidades` | 5.979 | funil: origem, etapa, valor, motivo de perda |
| `carteira` | 3.637 | vínculo vendedor ↔ cliente, com vigência |
| `vendedores` | 42 | região, admissão, desligamento, meta |

**A sujeira é proposital.** CNPJ em três formatos, data em dois, cliente
duplicado, devolução como quantidade negativa, vendedor desligado com carteira
ativa. Limpar isso é o conteúdo da noite 2 — não conserte o gerador.

---

## 📁 Estrutura

```
aulas/         uma pasta por noite, autocontida
material/      PRD da imersão, gerador do dataset, slides
scripts/       run_sql.py — roda um .sql no warehouse
dados/         dataset gerado (não versionado — reproduza com o comando acima)
```

## 🔑 Convenções

- Catálogo `rota_perfume`, schemas `bronze` / `silver` / `gold`.
- Tabelas e colunas em snake_case e português, iguais às do CSV.
- A bronze guarda o dado como veio, **com a sujeira**.
- Sempre passe `--profile` nos comandos do Databricks.
