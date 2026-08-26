# Prompt 2 · Treino — e o modelo vira objeto de catálogo

**Entrega:** modelo treinado, registrado no Unity Catalog, com alias
`@challenger` e as métricas gravadas em tabela. **Deploy nº 2 da noite.**

> O `.fit()` são duas linhas e é a parte menos interessante. O que importa
> aqui é que o modelo **entra no catálogo** — do lado das tabelas, com `GRANT`,
> linhagem e versão. É a diferença entre um arquivo `.pkl` no Drive de alguém e
> um ativo da empresa.

---

## O que mostrar antes

**1 · A pergunta para a sala, antes de qualquer código**

> *"Para quem o vendedor deve ligar amanhã?"*

Deixe responderem. Vem sempre alguma variação de duas:
**"para quem parou de comprar"** ou **"para quem compra mais"**.

Anote as duas na tela. Você vai medir as duas em cinco minutos.

**2 · Onde o modelo vai morar — e por que isso é o ponto**

Abra o **Catalog Explorer** em `lakehouse_rotaperfume.gold` e mostre que só
existem tabelas e views.

```sql
SHOW TABLES IN lakehouse_rotaperfume.gold;
```

> *"No fim deste prompt vai aparecer uma coisa nova nessa lista, e não é
> tabela. É o modelo. Mesmo catálogo, mesmo `GRANT`, mesma linhagem. É isso
> que muda quando o registro de modelos é o Unity Catalog e não uma pasta."*

**3 · O que existe hoje de MLflow: nada**

```bash
databricks experimental aitools tools query \
  "SELECT COUNT(*) FROM lakehouse_rotaperfume.information_schema.tables WHERE table_schema='gold'" \
  --profile projeto-dados-ia
```

Abra a aba **Experiments** no workspace: vazia. Daqui a dez minutos ela tem um
experimento com o histórico de cada treino.

---

**Enquanto ele trabalha, você explica:**

- **O baseline vem antes do modelo.** A régua honesta é a regra que o gerente
  usaria de graça. Se o modelo não ganhar dela, ele não deveria existir — e o
  prompt 4 vai transformar isso em teste que quebra o job.
- **Alias, não estágio.** O UC aposentou `Staging`/`Production`. Tem
  `@prod` e `@challenger`, que são apelidos móveis. Quem consome escreve
  `models:/…@prod` e nunca precisa saber número de versão — e reverter é o
  mesmo comando com outro número.
- **Treinar e promover são tarefas diferentes.** O treino apresenta um
  candidato; a promoção decide. Juntar as duas é como fazer deploy direto na
  main: funciona até o dia em que o retreino sai ruim às 6h da manhã.
- **Sobre a escolha do algoritmo:** `HistGradientBoostingClassifier` do
  scikit-learn, não XGBoost. Não é preferência técnica — no serverless do Free
  Edition hoje, o XGBoost **treina e registra, mas não carrega de volta**
  (conflito de versão com o scikit-learn instalado). Você só descobre na tarefa
  seguinte. Menos dependência, menos surpresa ao vivo.

---

## O prompt

```
Continue o bundle em aulas/aula-02-engenharia-de-dados/rotaperfume/.
gold.features_treino está pronta, com 2.815 clientes e o rótulo comprou_30d.

1. src/ml/12-treino.py — notebook Python (serverless).

   ORDEM DO NOTEBOOK, que é a ordem da aula:

   a) Carregue gold.features_treino em pandas (2.815 linhas cabem folgado —
      não force Spark onde não precisa) e separe treino/teste 75/25 com
      stratify e random_state=42.

   b) MEÇA O BASELINE ANTES DE TREINAR:
      - AUC ordenando por -recencia_dias ("ligue para quem comprou recente")
      - AUC ordenando por frequencia_pedidos ("ligue para quem compra mais")
      O maior dos dois é a régua. Imprima os dois, e imprima 0.5 do lado
      para lembrar que esse é o valor de jogar uma moeda.

   c) Treine um HistGradientBoostingClassifier (sklearn nativo — já vem no
      serverless, ao contrário do XGBoost, que na versão atual registra mas
      não carrega de volta). max_iter=200, learning_rate=0.08, max_depth=5,
      random_state=42.

   d) mlflow.sklearn.autolog(log_models=False) e mlflow.set_registry_uri
      ("databricks-uc") ANTES de qualquer log — sem isso o modelo vai para o
      registro antigo, fora do Unity Catalog.

      O experimento fica em /Users/<current_user()>/rotaperfume/propensao_compra.
      ATENÇÃO: mlflow.set_experiment NÃO cria a pasta pai, e o erro que volta
      é "BAD_REQUEST: For input string: None", que não fala nada de pasta.
      Crie antes com WorkspaceClient().workspace.mkdirs(...).

   e) Registre com mlflow.sklearn.log_model(modelo, artifact_path="model",
      input_example=..., registered_model_name="<catalogo>.gold.propensao_compra").
      Use artifact_path, NÃO name: o serverless traz MLflow 2.x e o argumento
      name só existe no MLflow 3.

   f) Aponte o alias @challenger para a versão registrada. NÃO aponte @prod:
      isso é decisão da tarefa de promoção. A única exceção é quando @prod
      ainda não existe — aí o candidato assume, porque não há o que comparar.

   g) Importância por permutação (permutation_importance com scoring="roc_auc",
      n_repeats=5). HistGradientBoosting não tem feature_importances_, e a
      permutação é mais honesta: mede o quanto o AUC piora sem a coluna.
      Grave o ranking em gold.modelo_importancia.

   h) Grave gold.modelo_validacao: as previsões do CONJUNTO DE TESTE ao lado
      do rótulo real. É a única base honesta para medir calibragem depois.

   i) Grave uma linha em gold.modelo_metricas (append) com: versão, run_id,
      data de corte, linhas de treino e teste, taxa de positivos, AUC,
      average precision, baseline, ganho sobre o baseline e a feature mais
      importante. Os testes do prompt 4 leem esta tabela.

   j) dbutils.notebook.exit com versão, AUC, baseline e ganho em JSON.

2. Acrescente a tarefa ml_treino ao pipeline, depois de ml_features.

3. Rode validate, deploy e run com --profile projeto-dados-ia.
```

---

## Como verificar a feature

**1 · O baseline — o momento da noite**

Abra a saída da tarefa `ml_treino` e mostre as três linhas:

```
AUC ordenando por recência    0.4329
AUC ordenando por frequência  0.6432
AUC de jogar uma moeda        0.5000
```

**Pare aqui.** É o slide que a sala não espera:

> *"Olhem a primeira linha. 'Ligue para quem comprou mais recentemente' — a
> resposta que metade de vocês deu há cinco minutos, e que qualquer gerente
> comercial daria — tem AUC de 0,433. **É pior do que jogar uma moeda.***
>
> *E não é acaso, é o negócio: distribuição funciona por ciclo de reposição.
> Quem acabou de receber a mercadoria é justamente quem NÃO vai comprar agora.
> A intuição não está imprecisa, ela está invertida."*

```sql
-- a prova, em SQL, para quem quiser conferir na mão
SELECT ROUND(baseline_recencia_auc, 4)   AS ligar_para_quem_comprou_recente,
       ROUND(baseline_frequencia_auc, 4) AS ligar_para_quem_compra_mais,
       ROUND(auc, 4)                     AS o_modelo
FROM lakehouse_rotaperfume.gold.modelo_metricas
ORDER BY _treinado_em DESC LIMIT 1;
-- 0,4329 · 0,6432 · 0,8667
```

**2 · O modelo ganhou, e dá para dizer de quanto**

```sql
SELECT versao, ROUND(auc, 4) AS auc, ROUND(baseline_auc, 4) AS baseline,
       ROUND(ganho_sobre_baseline, 4) AS ganho,
       linhas_treino, linhas_teste, ROUND(taxa_positiva, 4) AS taxa_positiva
FROM lakehouse_rotaperfume.gold.modelo_metricas
ORDER BY _treinado_em DESC LIMIT 1;
-- versão 1 · AUC 0,8667 · baseline 0,6432 · ganho +0,2235 · 2.111 / 704
```

**3 · A feature nº 1 é a que a gente inventou**

```sql
SELECT feature, ROUND(peso, 5) AS quanto_o_auc_piora_sem_ela
FROM lakehouse_rotaperfume.gold.modelo_importancia
ORDER BY peso DESC LIMIT 8;
```

O topo é **`atraso_relativo`** — a coluna que não veio de biblioteca nenhuma.

> *"A coluna que mais pesa neste modelo não estava em nenhum dataset. Ela
> nasceu de saber que 'sumiu há 20 dias' significa coisas opostas para quem
> compra toda semana e para quem compra por trimestre. Isso não é ciência de
> dados — é conhecimento de negócio, escrito como divisão."*

**4 · O modelo está no catálogo, do lado das tabelas**

Abra o **Catalog Explorer** → `lakehouse_rotaperfume` → `gold`. Agora tem
`propensao_compra` na lista, com ícone de modelo.

```bash
databricks registered-models get lakehouse_rotaperfume.gold.propensao_compra \
  --profile projeto-dados-ia
```

Clique em **Lineage**: ele aponta para `gold.features_treino`, que aponta para
`fato_vendas`, que aponta para a silver, que aponta para a bronze.

> *"A linhagem vai do CSV que chegou às 6h da manhã até o modelo que decide
> para quem ligar. Isso não é bonito de ver — é o que permite responder
> 'por que este cliente entrou na lista?' sem abrir um notebook."*

**5 · O histórico de treinos existe desde o primeiro dia**

Abra **Experiments** → `rotaperfume/propensao_compra`. Um run, com parâmetros,
métricas e o artefato.

> *"Rode de novo amanhã e aparece um segundo run. Em três meses, quando alguém
> perguntar por que o número mudou, a resposta é uma tela — não uma
> arqueologia no Git."*

---

## Se der errado ao vivo

| Sintoma | Causa | Correção em um prompt |
|---|---|---|
| `BAD_REQUEST: For input string: "None"` | A pasta pai do experimento não existe | `WorkspaceClient().workspace.mkdirs(...)` antes do `set_experiment` |
| `Object of type Decimal is not JSON serializable` | Alguma feature ficou `DECIMAL` | Falta `.cast("double")` no prompt 1 |
| `log_model() got an unexpected keyword argument 'name'` | Sintaxe do MLflow 3 num MLflow 2.22 | Troque `name=` por `artifact_path=` |
| O modelo não aparece no Catalog Explorer | Faltou `set_registry_uri("databricks-uc")` | Ele foi para o registro antigo do workspace |
| `No module named 'xgboost'` | XGBoost não vem no serverless | Use `HistGradientBoostingClassifier`; declarar a dependência resolve o import, mas o modelo não carrega de volta depois |
| AUC muito diferente do da tela | `random_state` diferente de 42 | A seed é fixa em todo o projeto |

**Tempo medido:** ~2 minutos, dos quais metade é a importância por permutação.

---

## O que fica de pé

| Objeto | O quê |
|---|---|
| `gold.propensao_compra` | modelo no Unity Catalog, versão 1, alias `@challenger` e `@prod` |
| `gold.modelo_metricas` | uma linha por treino: AUC 0,8667 · baseline 0,6432 |
| `gold.modelo_importancia` | 22 features ranqueadas por permutação |
| `gold.modelo_validacao` | 704 previsões do holdout, com o rótulo real |
| Job | `rotaperfume_pipeline` com 14 tarefas |
