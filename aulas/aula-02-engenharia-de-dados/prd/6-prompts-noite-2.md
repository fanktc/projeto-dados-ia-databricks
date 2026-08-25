# Os 6 prompts da Noite 2

**Imersão Jornada de Dados · Engenharia de dados · Terça 25/08 · 19h30**

> **Revisado com os dados reais da noite 1.** 445 certificados, nota 9,4, e a
> composição real da sala: **73% já trabalha com dados ou está migrando** — bem
> acima dos 42% que a base de inscritos sugeria.
>
> **A consequência: pode ir mais fundo do que o plano original.** Das 22 pessoas
> que deram nota 7 ou menos, 18 já trabalham com dados. O público sênior achou
> a aula 1 rasa. A terça precisa entregar densidade técnica.

---

## A ideia central da noite

Seis prompts, **seis deploys**. Não é um projeto que aparece pronto no fim: é
um bundle que nasce vazio no prompt 1 e ganha uma camada por prompt. O mesmo
job — `rotaperfume_pipeline` — começa com **uma** tarefa e termina com **doze**.

**A tela que conta a história é o DAG do job.** Abra ele depois de cada deploy
e mostre o desenho crescendo:

```
prompt 1   raw
prompt 2   raw → bronze
prompt 3   raw → bronze → silver ×4
prompt 4   raw → bronze → silver ×4 → dimensões → fato → marts → testes
prompt 5   + dashboard versionado no bundle
prompt 6   + views de negócio, auditoria de metadado e Genie
```

**Isto foi rodado inteiro, do catálogo vazio até o Genie respondendo.** Os seis
deploys deram verde e os 11 testes passam. Os tempos medidos estão no fim de
cada prompt, e as armadilhas que apareceram no caminho já estão escritas dentro
deles — você não vai tropeçar nas mesmas.

> **A aula 04 morreu, e por um bom motivo.** Deploy não é uma etapa no fim do
> projeto — é o que acontece toda vez que você termina alguma coisa. Por isso
> ele aparece seis vezes aqui, e não uma vez na quinta-feira.

---

## Os seis

| # | Entrega | Arquivo | Deploy |
|---|---|---|---|
| 1 | **Raw** — bundle, catálogo como código, CSVs no Volume | [`prompt-01-raw.md`](prompt-01-raw.md) | 1ª |
| 2 | **Bronze** — 10 tabelas Delta, sujeira preservada | [`prompt-02-bronze.md`](prompt-02-bronze.md) | 2ª |
| 3 | **Silver** — limpeza com contrato de qualidade | [`prompt-03-silver.md`](prompt-03-silver.md) | 3ª |
| 4 | **Gold** — dimensões, fato, marts e os 9 testes | [`prompt-04-gold.md`](prompt-04-gold.md) | 4ª |
| 5 | **Dashboard** — AI/BI versionado no bundle | [`prompt-05-dashboard.md`](prompt-05-dashboard.md) | 5ª |
| 6 | **Agentes de IA** — metadado, views de negócio, Genie | [`prompt-06-agentes.md`](prompt-06-agentes.md) | 6ª |

E antes de todos eles, o que prova que os seis bastam:

| — | **Reset** — apaga o catálogo, o bundle e o código | [`prompt-00-reset.md`](prompt-00-reset.md) | — |

---

## Os números que têm que aparecer

Todos medidos na execução real, com `seed 42`:

| Onde | Número |
|---|---|
| Raw no Volume | 10 arquivos · 14,7 MB · 313.551 linhas |
| Bronze | 10 tabelas · `itens_pedido` com 197.724 |
| Silver · clientes | 3.000 (eram 3.040 — 40 CNPJ duplicados) |
| Silver · receita | **R$ 102.303.828,05** — o mesmo da noite 1 |
| Silver · sujeira tratada | 3.443 datas · 1.111+223+309 CNPJ · 2.327 devoluções · 957 cancelados · 76 SKU fora de linha · 441 carteiras órfãs |
| Gold · `fato_vendas` | 191.080 linhas · R$ 102.303.828,05 |
| Gold · bruto vendido | R$ 103.568.586,35 (a diferença de R$ 1,26 mi é a devolução) |
| Gold · margem | R$ 41,1 mi · 40,2% |
| Marca líder | Layali R$ 18,4 mi líquido (18,6 bruto) |
| Margem por categoria | Kit Presente 33,0% · Óleo Concentrado 49,9% |
| Clientes em risco | 503 clientes · R$ 836 mil/mês de receita parada |
| Testes | 9 de qualidade + 2 de metadado, todos passando |

---

## O que muda em relação ao plano original

| Antes | Agora | Por quê |
|---|---|---|
| Explicar o que é medallion | Assumir que sabem, focar na decisão de projeto | 73% é técnico |
| Deploy só na noite 4 | Deploy 6 vezes, um por prompt | Deploy é rotina, não evento |
| Prompt 1 já criava a bronze | Prompt 1 é raw: arquivo no Volume | Raw ≠ bronze, e a diferença importa |
| Silver simples | Silver com CONSTRAINT no Delta | Densidade para o sênior |
| Mostrar código linha a linha | Mostrar decisão e trade-off | Eles leem código sozinhos |
| Dashboard como conceito | Dashboard como código versionado | Diferencial que quase ninguém ensina |

---

## Como conduzir

| Regra | Por quê |
|---|---|
| Um prompt por entrega | O aluno vê começo, meio e fim |
| Fale enquanto ele trabalha | O tempo de espera vira aula |
| Abra o DAG depois de cada deploy | É a tela que conta a história da noite |
| Abra **"O que mostrar antes"** antes de colar o prompt | O contraste é o que faz a entrega valer — sem o problema na tela, a solução não impressiona |
| Feche com **"Como verificar a feature"** | O prompt seguinte depende do anterior, e a sala precisa ver o número, não ouvir que deu certo |
| Não corrija tudo ao vivo | Se der ruim, ajuste num segundo prompt curto — isso ensina mais |

**Orçamento:** ~9 minutos por prompt, dos quais 5 a 6 são de fala sua.

---

## Cronograma

| Tempo | Bloco |
|---|---|
| 00:00–00:08 | Abertura, recap da noite 1 e o contrato da terça |
| 00:08–00:20 | Setup local — CLI, `bundle init`, Claude Code, MCP e guard rails |
| 00:20–00:26 | Onde vamos chegar, e por que a gente constrói de trás para frente |
| 00:26–00:35 | **Prompt 1 · Raw** |
| 00:35–00:44 | **Prompt 2 · Bronze** |
| 00:44–00:58 | **Prompt 3 · Silver** — o mais longo. Não corte. |
| 00:58–01:10 | **Prompt 4 · Gold** e a validação contra o número de ontem |
| 01:10–01:18 | **Prompt 5 · Dashboard** |
| 01:18–01:28 | **Prompt 6 · Agentes de IA** — o fechamento |
| 01:28–01:32 | Recap e gancho para a quarta |
| 01:32–02:00 | Dúvidas |

---

## Plano de contingência

| Situação | O que fazer |
|---|---|
| Claude Code demora demais | Fale mais. O tempo de espera é seu, não dele. |
| Código sai errado | Corrija com um segundo prompt curto. Ensina mais que acertar de primeira. |
| Erro que você não resolve em 2 min | Branch `gabarito`: `git checkout gabarito -- aulas/aula-02-engenharia-de-dados/rotaperfume/` |
| Precisa começar do zero de novo | `bash prd/00-reset.sh projeto-dados-ia --apagar` e recomeça pelo prompt 1 |
| Estourou o tempo | Corte o **prompt 5**. Dashboard já foi visto ontem; o 6 é o fechamento. |
| Cota do Free Edition travou | Plano B em DuckDB — os prompts de silver e gold funcionam quase iguais |

> **Rode os seis antes da aula e commite numa branch `gabarito`.** Você não
> precisa usar. Mas precisa ter.

---

## As seis armadilhas que já foram pagas

Cada uma custou tempo na preparação e está documentada dentro do prompt onde
aparece. Se alguma escapar ao vivo, a tabela "Se der errado" no fim de cada
prompt resolve em uma frase.

| # | Armadilha | Onde |
|---|---|---|
| 1 | O bundle **não consegue criar catálogo** no Free Edition (Default Storage). Só a UI e o SQL conseguem | prompt 1 |
| 2 | `mode: development` prefixa os **schemas** do UC: `bronze` vira `dev_fulano_bronze` e todo o SQL quebra | prompt 1 |
| 3 | `to_date` **aborta** a query em ANSI mode, não retorna nulo. Sempre `try_to_date` | prompt 3 |
| 4 | A constraint intuitiva `valor_liquido >= 0` **falha**: 135 pedidos têm saldo negativo por devolução, e é legítimo | prompt 3 |
| 5 | As etapas do funil são `Fechado ganho`/`Fechado perdido`, não `Ganha`/`Perdida` | prompt 3 |
| 6 | O Genie exige listas **ordenadas** e ids de **32 hex** em cada pergunta | prompt 6 |

---

## Ganchos da noite 1 para referenciar

Continuidade é o que faz a turma sentir que é um projeto só, e não quatro aulas:

- Subiram as 10 tabelas **clicando, uma por uma** → **prompt 2** é a resposta
- Criaram catálogo e schema **na interface** → **prompt 1** é a resposta
- Viram o CNPJ em 3 formatos e a data em 2 → **prompt 3** é a resposta
- A query do `exemplo-04` **quebrou** por causa das datas → `try_to_date` no prompt 3
- Você plugou o Genie na bronze avisando que podia errar → **prompt 6** é a resposta
- Você falou que *one-shot prompt* é o jeito errado → os 6 prompts são o jeito certo
- 24% pediram informação sobre as trilhas espontaneamente → eles estão comprando
