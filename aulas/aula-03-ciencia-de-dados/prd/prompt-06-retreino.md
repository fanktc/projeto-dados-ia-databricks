# Prompt 6 · Retreino — quem decide se o modelo novo entra

**Entrega:** a tarefa de promoção, o histórico de decisões e o rollback em um
comando. **Deploy nº 6 — o último da noite.**

> **O fechamento, e o assunto que separa quem já colocou modelo em produção de
> quem só treinou.** Retreinar é fácil: é a mesma tarefa rodando de novo. A
> parte que quase ninguém escreve é *quem decide se o modelo novo pode
> substituir o que está rodando.*

---

## O que mostrar antes

**1 · O modelo já está velho, e ninguém percebeu**

```sql
SELECT versao, ROUND(auc, 4) AS auc, data_corte, _treinado_em
FROM lakehouse_rotaperfume.gold.modelo_metricas ORDER BY _treinado_em DESC;
```

> *"Esse modelo foi treinado com dado até 1º de agosto. Todo dia que passa ele
> fica um dia mais desatualizado — e a única coisa que NÃO muda é a confiança
> com que ele responde. Ele não avisa que está velho. Nunca avisa."*

**2 · A pergunta que decide a arquitetura**

Escreva as duas opções na tela e pergunte qual a sala escolheria:

| | O que dá errado |
|---|---|
| **Todo retreino vira produção** | o retreino ruim de um sábado entra sozinho às 6h e ninguém vê |
| **Ninguém troca sem aprovação manual** | dá trabalho, dá medo, e em 2026 o modelo de 2024 ainda está decidindo |

> *"As duas estão erradas, e o problema é o mesmo: a decisão não está escrita
> em lugar nenhum. Ela acaba acontecendo por omissão."*

**3 · O que acontece hoje se você rodar o pipeline de novo**

```bash
databricks bundle run rotaperfume_pipeline --target dev --profile projeto-dados-ia
```

> *"Vai treinar uma versão nova e apontar `@prod` para ela. Sem perguntar
> nada, sem comparar com nada. É exatamente o primeiro caso da tabela."*

---

**Enquanto ele trabalha, você explica:**

- **Alias é o mecanismo inteiro.** `@prod` e `@challenger` são apelidos móveis.
  A tarefa de score lê `models:/…@prod` e nunca soube qual versão está usando —
  e é isso que faz promover e reverter custarem **um comando**, sem alterar
  uma linha de código em lugar nenhum.
- **A margem existe por causa de ruído.** AUC oscila entre execuções por causa
  do sorteio do split. Trocar o modelo de produção por causa de ruído é pior do
  que não trocar: cada troca é uma explicação a dar quando o número mudar.
- **A recusa também vira linha.** O histórico registra o que **não** foi
  promovido e por quê. Daqui a seis meses, "por que ainda estamos na versão 3?"
  tem resposta em SQL.
- **Isso é code review, aplicado a modelo.** Ninguém faz merge direto na main
  porque os testes passaram na máquina de quem escreveu. Modelo é a mesma
  coisa, e a única diferença é que quase ninguém trata assim.

---

## O prompt

```
Continue o bundle em aulas/aula-02-engenharia-de-dados/rotaperfume/.
O pipeline tem 17 tarefas e o modelo está em @prod.

1. ALTERE src/ml/12-treino.py: em vez de apontar @prod, aponte @challenger.
   O treino apresenta um candidato; ele não promove nada.
   Exceção: se @prod ainda não existir, o candidato assume — não há o que
   comparar na primeira versão.

2. src/ml/16-promocao.py — notebook Python. A decisão, com esta regra:

     não existe @prod                          → promove
     challenger já é o @prod                   → não faz nada
     AUC do challenger > AUC do prod + 0.01    → promove
     diferença dentro de 0.01                  → NÃO promove (empate técnico)
     challenger pior                           → não promove

   As métricas das duas versões vêm de gold.modelo_metricas, não da API do
   MLflow: assim a decisão fica auditável em SQL por quem não usa MLflow.

3. Grave gold.modelo_promocoes: versão do challenger, versão do prod anterior,
   os dois AUCs, se promoveu e o MOTIVO em texto. As recusas também entram —
   elas são metade do valor da tabela.

4. Documente no notebook, em markdown, como fazer rollback:
   client.set_registered_model_alias(MODELO, "prod", <versao>)

5. Acrescente a tarefa ml_promocao ao pipeline ENTRE ml_treino e ml_score.
   A ordem final: ml_features → ml_treino → ml_promocao → ml_score →
   ml_testes → ml_carteira_do_dia.

6. Rode validate, deploy e run com --profile projeto-dados-ia.
```

---

## Como verificar a feature

**1 · Rode o pipeline de novo e mostre que ele RECUSOU o modelo novo**

```bash
databricks bundle run rotaperfume_pipeline --target dev --profile projeto-dados-ia
```

```sql
SELECT versao_challenger, versao_prod_anterior,
       ROUND(auc_challenger, 4) AS auc_novo,
       ROUND(auc_prod_anterior, 4) AS auc_atual,
       promovido, motivo
FROM lakehouse_rotaperfume.gold.modelo_promocoes ORDER BY _decidido_em;
```

| challenger | prod | AUC novo | AUC atual | promovido | motivo |
|---|---|---|---|---|---|
| 1 | — | 0,8667 | — | ✅ | não havia modelo em produção |
| 2 | 1 | 0,8667 | 0,8667 | ❌ | diferença de +0,0000 não passa a margem de 0,01: empate técnico |

**Esta é a tela do prompt.** Pare nela:

> *"O pipeline acabou de treinar um modelo novo e **se recusou a colocá-lo em
> produção**. E ele está certo: o dado é o mesmo, a seed é a mesma, o modelo é
> idêntico. Trocar a versão de produção por um empate seria puro churn — mais
> uma versão para explicar, zero de ganho.*
>
> *Repare que ninguém precisou aprovar nada, e ninguém precisou confiar em nada.
> A regra está escrita, roda toda noite, e deixa registro."*

**2 · O alias, na prática**

```bash
databricks registered-models get lakehouse_rotaperfume.gold.propensao_compra \
  --profile projeto-dados-ia | grep -A3 aliases
```

Mostre no Catalog Explorer: a versão 2 existe, mas quem tem `@prod` é a 1.

```sql
-- e a tabela de score prova qual delas está de fato sendo usada
SELECT DISTINCT versao_modelo FROM lakehouse_rotaperfume.gold.score_propensao;
-- 1
```

**3 · O rollback, ao vivo, em um comando**

Esta é a demonstração final da noite. Force uma promoção e volte atrás:

```python
# num notebook, ou como célula do 16-promocao
from mlflow.tracking import MlflowClient
c = MlflowClient(registry_uri="databricks-uc")
c.set_registered_model_alias("lakehouse_rotaperfume.gold.propensao_compra", "prod", 2)
```

```bash
databricks bundle run rotaperfume_pipeline --target dev --profile projeto-dados-ia
```

```sql
SELECT DISTINCT versao_modelo FROM lakehouse_rotaperfume.gold.score_propensao;
-- 2 — o score inteiro passou a sair da versão 2
```

E volte:

```python
c.set_registered_model_alias("lakehouse_rotaperfume.gold.propensao_compra", "prod", 1)
```

> *"Rollback de modelo foi uma linha. Nenhum arquivo mudou, nenhum deploy
> aconteceu, a tarefa de score não sabe que alguma coisa mudou — ela sempre
> pediu `@prod`.*
>
> *Compare com o que costuma acontecer: alguém procura o `.pkl` certo no Drive,
> renomeia, sobe de novo e torce. É a mesma diferença entre `git revert` e
> restaurar um backup na mão."*

**4 · O pipeline completo — a tela que fecha as três noites**

```bash
databricks bundle run rotaperfume_pipeline --target dev --profile projeto-dados-ia
```

Abra o DAG e conte na tela:

```
raw → bronze → silver ×4 → dimensões → fato → marts → testes
                                             ├→ métricas → auditoria
                                             └→ ml_features → ml_treino →
                                                ml_promocao → ml_score →
                                                ml_testes → ml_carteira_do_dia
```

**18 tarefas. 19 testes que quebram o job.** Um `bundle run`.

> *"Isso começou terça-feira com um bundle vazio. Hoje ele conta a história
> inteira: o CSV chega às 6h, vira tabela, é limpo, é testado, vira modelo, o
> modelo é avaliado, promovido ou recusado, e sai do outro lado como a lista de
> quem o vendedor liga às 8h. Sem ninguém abrir o navegador."*

---

## Se der errado ao vivo

| Sintoma | Causa | Correção em um prompt |
|---|---|---|
| `RESOURCE_DOES_NOT_EXIST … @challenger` | O treino ainda aponta `@prod` | É o passo 1 do prompt: troque o alias no `12-treino.py` |
| Promove sempre, mesmo empatando | A comparação está usando `>=` | Tem que ser `> auc_prod + MARGEM` |
| `auc_challenger` vem nulo | A versão não tem linha em `modelo_metricas` | O treino grava com `append`; confira se rodou |
| O score continua na versão antiga | A tarefa de score rodou antes da promoção | `ml_promocao` tem que ficar **entre** treino e score |
| Duas versões na tabela de score | O score rodou no meio de uma troca | O teste 8 do prompt 4 pega isso e quebra o job |

**Tempo medido:** ~15 segundos a promoção. O pipeline completo, ~9 minutos.

---

## Fala de fechamento da noite

> *"Segunda-feira a gente escreveu uma query que quebrou por causa de data em
> dois formatos.*
>
> *Terça a gente transformou aquilo em camada: escrito uma vez, testado,
> agendado.*
>
> *Hoje o mesmo pipeline parou de responder o que aconteceu e passou a dizer o
> que fazer amanhã de manhã. E a coluna que mais pesa nesse modelo não veio de
> biblioteca nenhuma — veio de saber que, em distribuição, quem comprou ontem é
> justamente quem não compra hoje.*
>
> *A intuição do gerente comercial, medida, deu 0,433. Pior que jogar moeda. E
> não é porque ele é ruim no que faz — é porque ninguém tinha medido.*
>
> *Ciência de dados não é o algoritmo. O algoritmo tem três linhas e é igual
> para todo mundo. É saber o que perguntar, com que dado, e ter como provar que
> a resposta está certa."*

---

## O que fica de pé no fim da noite

| Camada | O quê |
|---|---|
| `gold.features_treino` · `features_cliente` | 22 features por cliente, mesma função, dois cortes |
| `gold.propensao_compra` | modelo no Unity Catalog, versionado, com `@prod` e `@challenger` |
| `gold.modelo_metricas` · `modelo_importancia` · `modelo_validacao` | AUC, ranking de features e o holdout |
| `gold.modelo_promocoes` | histórico de decisões — inclusive as recusas |
| `gold.score_propensao` | 2.816 clientes com probabilidade e faixa |
| `gold.carteira_do_dia` | 1.290 contatos priorizados, com motivo em português |
| Job | `rotaperfume_pipeline`, **18 tarefas**, **19 testes** que quebram |
