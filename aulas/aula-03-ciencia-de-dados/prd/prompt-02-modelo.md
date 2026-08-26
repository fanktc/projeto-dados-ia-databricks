# Prompt 2 · O modelo e o MLflow

**Slides que acompanham:** 23 a 37 (divisor *"O modelo"*, o problema escrito em
uma frase, o algoritmo em três linhas, **por que árvore e não Poisson**, **o que
é AUC**, vazamento de dado, o teste que quase ninguém escreve, divisor
*"MLflow"*, a pergunta de daqui a seis meses, o que o MLflow resolve, o modelo
do lado das tabelas).

**Entrega:** o modelo registrado no Unity Catalog e `gold.score_propensao` —
os 3.000 clientes com nota. **Deploy nº 2 da noite.**

> Este é o prompt do momento da noite. **Segure o baseline até aqui.** Ele é a
> única coisa da aula que a sala não espera.

---

## O que mostrar antes

**1 · Peça a resposta da sala — e escreva no quadro**

> *"Sem modelo nenhum. Você tem 200 ligações e 3.000 clientes. Qual coluna você
> ordena?"*

Vem sempre **"quem parou de comprar"** e **"quem compra mais"**. Anote as duas.
Daqui a dez minutos as duas viram número.

**2 · A régua: a taxa base que o prompt 1 mediu**

```sql
SELECT ROUND(100 * AVG(comprou_em_7d), 2) AS taxa_base_pct
FROM lakehouse_rotaperfume.gold.features_treino;
```

**~10,1%.** Vinte de cada duzentas.

> *"Se eu sortear 200 nomes num chapéu, essa é a fração que compra sozinha.
> Qualquer coisa que a gente construir hoje precisa ganhar disso — senão o
> projeto não se paga."*

**3 · O corte, desenhado no quadro antes de qualquer código**

```
|---- features até 31/07 ----|CORTE|---- alvo: comprou até 07/08? ----|
                          01/08/2026
```

> *"Se qualquer coluna à esquerda souber de algo à direita, o AUC vem 0,98 e o
> modelo quebra em produção. E não vai aparecer erro nenhum: vai aparecer
> sucesso."*

---

**Enquanto ele trabalha, você explica:**

- **Baseline não é formalidade — é a régua.** "AUC 0,87" não quer dizer nada
  sozinho. "Ganha do que a gente já fazia de graça" quer dizer tudo.
- **A métrica que vai para a reunião é `lift_top200`.** AUC é métrica de quem
  treina. O diretor pergunta quantos dos 200 compraram. São perguntas
  diferentes, e a segunda é a que paga a conta.
- **Vazamento parece sucesso.** É o único erro de ML que chega com print no
  grupo. A defesa não é atenção — é estrutural: função com data por parâmetro,
  coluna `_referencia` gravada, e um teste que **quebra o job se o AUC ≥ 0,99**.
- **O modelo vira objeto de catálogo.** Mesmo catálogo das tabelas, mesmo
  GRANT, mesma linhagem. Não é um `.pkl` no Drive de alguém que saiu da
  empresa.

---

## O prompt

```
Continue o mesmo bundle. As features estão em gold.features_treino e
gold.features_cliente.

Crie src/ml/12-modelo.py — um notebook Python para serverless. Nesta ordem:

1. BASELINE, antes de treinar qualquer coisa.
   Separe 25% de gold.features_treino como holdout, com random_state=42 e
   estratificado pelo alvo. No holdout, calcule roc_auc_score do alvo contra
   cada regra simples, usada como se fosse o score:
     a) -recencia_dias      ("ligue para quem comprou recentemente")
     b)  valor_total        ("ligue para quem compra mais")
     c)  atraso_relativo    ("ligue para quem está atrasado")
   Imprima os três lado a lado, com 0,5000 (a moeda) na mesma tabela.
   Guarde o melhor deles: é a régua do teste 1.

2. TREINO.
   HistGradientBoostingClassifier do scikit-learn, random_state=42.
   NÃO impute NULL: este algoritmo trata NaN nativamente, e as features de
   ritmo são NULL de propósito para quem tem um pedido só.
   NÃO use XGBoost: ele treina e registra, mas falha ao carregar de volta no
   serverless por conflito com scikit-learn 1.6.1 (__sklearn_tags__), e o erro
   só aparece uma tarefa depois.

3. AS DUAS MÉTRICAS.
   auc          — no holdout
   lift_top200  — pontue TODOS os clientes de features_treino por validação
                  cruzada out-of-fold (StratifiedKFold, 5 folds, shuffle,
                  random_state=42), ordene por score, pegue os 200 primeiros e
                  divida a taxa de compra deles pela taxa base.
                  Out-of-fold, e não só o holdout, porque a fila real é de 200
                  entre 3.000 — no holdout de 700 os 200 primeiros seriam 28%
                  da amostra, e o número sairia otimista.
                  Imprima também acertos_top200 (quantos dos 200 compraram).
                  Essa é a métrica que responde a pergunta do diretor.

4. IMPORTÂNCIA POR PERMUTAÇÃO, no holdout, n_repeats=5. Imprima o top 10.

5. MLFLOW.
   Antes de mlflow.set_experiment, crie a pasta pai com
   WorkspaceClient().workspace.mkdirs(...) — sem isso o erro é
   "BAD_REQUEST: For input string: None" e não menciona pasta nenhuma.
   O serverless tem MLflow 2.22: use log_model(..., artifact_path="modelo"),
   nunca o name= do MLflow 3.
   Registre em lakehouse_rotaperfume.gold.propensao_compra com
   mlflow.set_registry_uri("databricks-uc") e aponte o alias @prod para a
   versão recém-criada.
   Logue params, auc, lift_top200, acertos_top200 e a taxa base.

6. TRÊS TESTES QUE INTERROMPEM A TAREFA (assert, com mensagem em português):
   - o modelo ganha do MELHOR baseline por pelo menos 0,05 de AUC
   - auc < 0,99 — bom demais é vazamento, não competência
   - lift_top200 >= 2,5 — abaixo disso a fila não justifica o projeto

7. SCORE.
   Carregue o modelo com mlflow.sklearn.load_model("models:/...@prod") e use
   predict_proba — NÃO use pyfunc.predict, que devolve a classe e transforma
   a coluna inteira em zeros e uns.
   NÃO use mlflow.pyfunc.spark_udf: não roda no serverless
   (InvalidVersion: '18.x-aarch64-photon-scala2'). Traga para pandas: 3.000
   clientes cabem na memória com folga.
   Pontue com EXATAMENTE as colunas do treino, na mesma ordem, lendo
   modelo.feature_names_in_ — não confie na ordem das colunas da tabela.
   Grave gold.score_propensao com cliente_id (INT), score, a faixa
   (NTILE(4) sobre o score: Fria, Morna, Quente, Muito quente), _referencia e
   a versao do modelo — o número que veio do registro no UC.

8. AS MÉTRICAS TAMBÉM VIRAM TABELA — o Genie não lê MLflow, e daqui a seis
   meses ninguém abre a interface de experimento:

   gold.modelo_metricas     uma linha por treino: versao, auc, lift_top200,
                            acertos_top200, taxa_base, o AUC de cada um dos
                            três baselines, a feature nº 1 e _treinado_em
   gold.calibragem_holdout  faixa, clientes, compraram, taxa_de_compra e
                            score_medio, calculados no holdout — é a prova do
                            slide *Não é acurácia*, e a única que o comercial confere sozinho

Tabelas e colunas com COMMENT em português.

Registre a tarefa ml_modelo em resources/pipeline.job.yml, depois de
ml_features, e faça o deploy.
```

---

## Como verificar a feature

**1 · O baseline — o momento da noite**

Está impresso na saída da tarefa. Leia em voz alta, na ordem:

| A resposta | AUC | Dos 200, quantos compram |
|---|---|---|
| "ligue para quem sumiu há mais tempo" | **~0,37 — pior que moeda** | **0** |
| jogar uma moeda | 0,5000 | 20 |
| "ligue para quem compra mais" | ~0,62 | 44 |
| **o modelo** | **~0,85** | **75** |

> Referência medida fora do Databricks, com 12 das 20 features, `seed 42`,
> corte `2026-08-01` e janela de 7 dias. **O seu número vai sair na tela da
> tarefa — é ele que vale.** Se vier na mesma ordem de grandeza, está certo.

**Zero.** Dos 200 clientes que sumiram há mais tempo, nenhum comprou na semana
seguinte. Não é "um pouco pior": é a lista inteira desperdiçada.

> **A intuição comercial não está imprecisa — está invertida.** Distribuição
> funciona por ciclo de reposição: quem acabou de receber a mercadoria é
> justamente quem não compra agora. Ninguém tinha medido.

**2 · A prova que o comercial entende, sem falar em AUC**

```sql
SELECT faixa, clientes, compraram,
       ROUND(100 * taxa_de_compra, 1) AS pct_que_comprou
FROM lakehouse_rotaperfume.gold.calibragem_holdout
ORDER BY score_medio;
```

A taxa de compra tem que **subir** da faixa fria para a muito quente. Se sobe,
o score ordena — e ninguém precisa saber o que é curva ROC para conferir.

E a tabela que responde o diretor, com os três números do slide *Não é acurácia* lado a lado:

```sql
SELECT ROUND(100 * taxa_base, 1)      AS pct_aleatorio,
       acertos_top200,
       ROUND(lift_top200, 2)          AS lift,
       ROUND(auc, 4)                  AS auc
FROM lakehouse_rotaperfume.gold.modelo_metricas
ORDER BY _treinado_em DESC LIMIT 1;
```

**3 · O modelo é um objeto do catálogo, não um arquivo**

```sql
SHOW MODELS IN lakehouse_rotaperfume.gold;
```

Abra a tela do modelo no workspace ao lado da tela da tabela. **Mesmo
catálogo, mesma linhagem, mesmo GRANT.** É o slide *“Esse modelo ainda está bom?”* respondido: qual versão
está em produção, com que dado, treinada quando e por quem.

**4 · O teste que desconfia do sucesso**

Mostre a linha do `assert auc < 0.99` no código:

> *"Este job quebra se o resultado ficar bom demais. É a única defesa que
> funciona contra vazamento, porque vazamento não chega com erro — chega com
> elogio."*

---

## Se der errado

| Sintoma | Causa | Saída |
|---|---|---|
| `BAD_REQUEST: For input string: "None"` | `set_experiment` não cria a pasta pai | `WorkspaceClient().workspace.mkdirs(...)` antes |
| `AttributeError: __sklearn_tags__` | XGBoost registrado, sklearn 1.6.1 na carga | trocar por `HistGradientBoostingClassifier` |
| `InvalidVersion: '18.x-aarch64-photon-scala2'` | `pyfunc.spark_udf` no serverless | `mlflow.sklearn.load_model` + pandas |
| `score` só com 0 e 1 | `pyfunc.predict` devolve a classe | `predict_proba()[:, 1]` |
| `Object of type Decimal is not JSON serializable` | feature `DECIMAL` no registro | `.cast("double")` no prompt 1 |
| O assert do baseline quebrou o job | o modelo não ganhou da regra simples | **não conserte ao vivo** — é a aula acontecendo. Mostre a mensagem e discuta |
