# 🏗️ Dia 2: Engenharia de dados | Imersão Jornada de Dados

Ontem a query quebrou por causa das datas em dois formatos, e a gente resolveu
no braço com um `try_to_date` dentro do `SELECT`. Funcionou — para uma query.

Hoje isso vira **camada**: escrito uma vez, testado, agendado, e todo mundo que
consultar o dado depois já pega ele limpo.

> **Promessa da noite:** o projeto passa a rodar sozinho.
> **Pergunta da noite:** *"Como faço para não resolver o mesmo problema toda vez?"*
> **Formato:** [6 prompts, 6 deploys](prd/6-prompts-noite-2.md). O projeto inteiro
> nasce de um catálogo vazio.

---

## 🧠 A ideia da noite: deploy é rotina, não evento

A aula 4 original era "deploy". Ela morreu, e por um bom motivo: deploy não é
uma etapa no fim do projeto. É o que acontece **toda vez que você termina
alguma coisa**.

Por isso ele aparece seis vezes aqui. Um bundle que nasce vazio e ganha uma
camada por prompt — o mesmo job começa com **uma** tarefa e termina com **doze**:

```
prompt 1   raw
prompt 2   raw → bronze
prompt 3   raw → bronze → silver ×4
prompt 4   raw → bronze → silver ×4 → dimensões → fato → marts → testes
prompt 5   + dashboard versionado no bundle
prompt 6   + views de negócio, auditoria de metadado e Genie
```

A tela que conta essa história é o DAG do job. Abra depois de cada deploy.

---

## 📋 Os seis prompts

Cada um está num arquivo próprio, com o prompt copiável, o que falar enquanto
o Claude Code trabalha, como validar ao vivo e uma tabela **"se der errado"**.

| # | Entrega | Arquivo |
|---|---|---|
| — | **Reset** — apaga tudo, para provar que os seis bastam | [`prompt-00-reset.md`](prd/prompt-00-reset.md) |
| 1 | **Raw** — bundle, catálogo, Volume e conferência de chegada | [`prompt-01-raw.md`](prd/prompt-01-raw.md) |
| 2 | **Bronze** — 10 tabelas Delta, sujeira preservada | [`prompt-02-bronze.md`](prd/prompt-02-bronze.md) |
| 3 | **Silver** — limpeza com contrato de qualidade | [`prompt-03-silver.md`](prd/prompt-03-silver.md) |
| 4 | **Gold** — dimensões, fato, marts e os 9 testes | [`prompt-04-gold.md`](prd/prompt-04-gold.md) |
| 5 | **Dashboard** — AI/BI versionado no bundle | [`prompt-05-dashboard.md`](prd/prompt-05-dashboard.md) |
| 6 | **Agentes de IA** — metadado, views de negócio, Genie | [`prompt-06-agentes.md`](prd/prompt-06-agentes.md) |

O contexto do projeto que o Claude Code lê antes de tudo está em
[`prd/CLAUDE.md`](prd/CLAUDE.md).

---

## 🧹 A sujeira da noite 1, e como cada uma some

Cada item foi **medido**, não estimado:

| Problema | Quantos | Como a silver resolve |
|---|---|---|
| Data em `dd/MM/yyyy` | 3.443 pedidos (12%) | `coalesce(try_to_date(c,'yyyy-MM-dd'), try_to_date(c,'dd/MM/yyyy'))` |
| CNPJ pontuado | 1.111 clientes | `regexp_replace(cnpj, '[^0-9]', '')` |
| CNPJ com espaço em volta | 223 clientes | `trim()` antes de tudo |
| CNPJ com zero à esquerda | 309 clientes | `lpad(..., 14, '0')` — e nunca converter para número |
| Mesmo CNPJ, cadastros diferentes | 40 clientes | `row_number()` por CNPJ, mantém o mais antigo |
| Devolução como quantidade negativa | 2.327 itens | coluna `devolucao` + `quantidade_abs`, **sem descartar** |
| Cancelado com valor zerado | 957 pedidos | flag `cancelado` explícita |
| SKU descontinuado em venda | 76 itens | join com produtos, coluna `sku_descontinuado` |
| Carteira ativa de vendedor desligado | 441 vínculos | coluna `orfao_vendedor_desligado`, que **expõe** em vez de consertar |

---

## 🔢 O que tem que aparecer na tela

Rodado de ponta a ponta, do catálogo vazio, com `seed 42`:

| Onde | Número |
|---|---|
| Raw no Volume | 10 arquivos · 14,7 MB · 313.551 linhas |
| Silver · clientes | 3.000 (eram 3.040) |
| **Silver · receita** | **R$ 102.303.828,05** — o mesmo da noite 1 |
| Gold · `fato_vendas` | 191.080 linhas · R$ 102.303.828,05 |
| Gold · bruto vendido | R$ 103.568.586,35 |
| Gold · margem | R$ 41,1 mi · 40,2% |
| Marca líder | Layali R$ 18,4 mi líquido · R$ 18,6 mi bruto |
| Margem por categoria | Kit Presente 33,0% · Óleo Concentrado 49,9% |
| Outubro/2025 · Janeiro/2026 | R$ 7,02 mi · R$ 2,46 mi |
| Clientes em risco | 503 · R$ 836 mil/mês parados |
| Testes | 9 de qualidade + 2 de metadado, todos passando |

**O teste que mais importa é o primeiro:** limpeza **não pode mudar o
faturamento**. Se mudou, você jogou dado fora sem querer — e três meses depois
alguém compara dois relatórios numa reunião e a discussão vira sobre qual
sistema está certo.

### 🔍 A armadilha que quase passou

A primeira versão do `fato_vendas` deixava a devolução **de fora**. Parecia
certo: "receita é o que vendeu". O resultado: a gold mostrava R$ 103,6 mi e a
silver R$ 102,3 mi. **R$ 1,26 milhão de diferença entre duas camadas do mesmo
pipeline.**

A devolução ficou **dentro** do fato, com flag e valor negativo:

```sql
SUM(receita)                                  -- R$ 102,3 mi, igual à silver
SUM(receita) FILTER (WHERE NOT devolucao)     -- R$ 103,6 mi, o bruto vendido
```

Quem quer cada número tem como pedir, e os dois reconciliam.

### 🧨 A constraint que estava errada

A regra `valor_liquido >= 0` parece óbvia, e **falhou em 135 pedidos**. A
investigação mostrou que os 135 têm item devolvido: o saldo do pedido virou
negativo, e é negócio legítimo. A regra errada era a nossa.

É exatamente para isso que a constraint serve — ela transformou uma suposição
em pergunta **antes** de a suposição virar número no dashboard.

---

## 🗂️ O projeto

```
rotaperfume/
├── databricks.yml                    o bundle, targets dev e prod
├── scripts/
│   ├── criar-catalogo.sh             o catálogo (por SQL — veja abaixo)
│   └── subir-raw.sh                  os CSVs para o Volume
├── resources/
│   ├── catalogo.yml                  schemas e volume como código
│   ├── pipeline.job.yml              o job de 12 tarefas
│   ├── dashboard.dashboard.yml       + dashboard-comercial.lvdash.json
│   └── genie.genie_space.yml         + comercial.geniespace.json
└── src/
    ├── raw/conferencia.py            os 10 arquivos chegaram?
    ├── bronze/ingestao.py            CSV → Delta, sem limpar nada
    ├── silver/01..04*.sql            a limpeza, com CONSTRAINT
    └── gold/05..10*.sql              dimensões, fato, marts, testes, views
```

### Como rodar

```bash
cd aulas/aula-02-engenharia-de-dados/rotaperfume
bash scripts/criar-catalogo.sh SEU-PERFIL
databricks bundle deploy --target dev --profile SEU-PERFIL
bash scripts/subir-raw.sh SEU-PERFIL
databricks bundle run rotaperfume_pipeline --target dev --profile SEU-PERFIL
```

### Para zerar e recomeçar

```bash
bash prd/00-reset.sh SEU-PERFIL          # simula
bash prd/00-reset.sh SEU-PERFIL --sim    # apaga de verdade
```

---

## ⚠️ Armadilhas medidas contra o workspace

Estas custaram tempo na preparação. Estão documentadas dentro do prompt onde
aparecem, com a correção em uma frase.

1. **O bundle não consegue criar catálogo no Free Edition.** Com Default
   Storage ligado, a API do Unity Catalog pede um `MANAGED LOCATION` que a
   conta gratuita não tem. Só a UI e o `CREATE CATALOG` em SQL conseguem — por
   isso existe o `scripts/criar-catalogo.sh`.

2. **`mode: development` prefixa os schemas do UC.** `bronze` viraria
   `dev_seunome_bronze` e todo o SQL da noite quebraria. O target `dev` não usa
   `mode`; o agendamento é pausado com `presets: trigger_pause_status: PAUSED`.

3. **`to_date` aborta a query em ANSI mode.** Data malformada levanta
   `CAST_INVALID_INPUT` em vez de virar `NULL`. Sempre `try_to_date`.

4. **`inferSchema` na bronze apaga evidência.** O CNPJ vira número e some com
   os 309 zeros à esquerda. A bronze lê tudo como texto, de propósito.

5. **`read_files` injeta `_rescued_data`.** Descarte com
   `SELECT * EXCEPT (_rescued_data)`. Passar `rescuedDataColumn => ''` cria uma
   coluna de nome vazio e o `CREATE TABLE` falha.

6. **`databricks fs cp` exige o esquema `dbfs:`**, mesmo para Volumes do UC.

7. **O Genie space exige listas ordenadas e ids de 32 hex** em cada pergunta e
   instrução. Gere os ids por hash do conteúdo, nunca aleatórios.

---

## 🤖 O quarto ambiente: Claude Code

Na noite 1 a pergunta foi respondida em três ambientes — Claude Web, SQL e
Genie. Os três **respondem**. O Claude Code é diferente: ele **constrói**.

| | Claude Web | SQL | Genie | **Claude Code** |
|---|---|---|---|---|
| Escala | ○ | ● | ● | ● |
| Reproduz | ○ | ● | ◐ | ● |
| Governado | ○ | ● | ● | ● |
| **Constrói** | ○ | ○ | ○ | **●** |

Três coisas ficam visíveis ao vivo, e é isso que o separa dos outros três:
**ele escreve o arquivo** (versionado no Git, não numa janela de chat que
some), **ele roda** (executa no workspace e lê o resultado de volta) e **ele
confere** (se a receita não bater, o teste quebra e ele corrige, em vez de
entregar um número errado com confiança).

> O Genie responde "qual foi a receita". O Claude Code entrega a tabela que
> passa a responder isso todo dia, sozinha.

E ele erra igual aos outros quando o dado está bagunçado. A diferença é que o
erro **aparece**: a query quebra, o teste falha, e você vê. Foi assim que este
repositório descobriu que `to_date` aborta em ANSI mode — e que a constraint
`valor_liquido >= 0` estava errada.

---

## ➡️ Amanhã

Com a `gold.fato_vendas` de pé e o Genie respondendo sobre dado limpo, as três
perguntas da diretoria deixam de ser consulta e viram modelo.
