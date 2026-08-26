# Prompt 4 · Os testes que quebram o job — agora do modelo

**Entrega:** oito testes de modelo em SQL, que interrompem o pipeline.
**Deploy nº 4 da noite.**

> **O prompt mais importante da noite, e o que quase nenhum curso ensina.**
> Ontem os testes perguntavam se o dado está certo. Hoje eles perguntam se o
> modelo está certo — e a diferença entre as duas coisas é a aula inteira.

---

## O que mostrar antes

**1 · A frase que organiza o bloco**

Escreva na tela, antes de qualquer query:

> **Um dado errado quebra. Um modelo ruim funciona.**

Deixe no ar por três segundos e explique:

> *"Se a receita vier nula, alguma coisa explode e alguém é avisado. Se o
> modelo ficar ruim, ele continua devolvendo número para todo mundo, na faixa
> certa, sem erro nenhum. O pipeline fica verde, o dashboard atualiza, e o
> vendedor liga para a lista errada por seis meses. Do ponto de vista do
> software, está tudo funcionando."*

**2 · Prove que o pipeline está cego para isso**

```sql
-- Os 11 testes de ontem continuam passando, e nenhum deles olha para o modelo
SELECT COUNT(*) AS testes_de_dado_existentes FROM lakehouse_rotaperfume.gold.fato_vendas WHERE 1=0;
```

Mostre a tarefa `testes_de_qualidade` verde no DAG e diga:

> *"Onze testes verdes. Se eu trocar o modelo por um que sorteia número
> aleatório, quantos deles ficam vermelhos?"*

A resposta é **nenhum**. Prove ao vivo, se tiver dois minutos:

```sql
-- um "modelo" que sorteia. A tabela continua com a cara certa.
CREATE OR REPLACE TABLE lakehouse_rotaperfume.gold._score_falso AS
SELECT cliente_id, rand(42) AS score_propensao,
       CASE WHEN rand(7) < .5 THEN 'Fria' ELSE 'Quente' END AS faixa
FROM lakehouse_rotaperfume.gold.features_cliente;

SELECT * FROM lakehouse_rotaperfume.gold._score_falso LIMIT 5;
-- Colunas certas, faixa certa, valores entre 0 e 1. Indistinguível do real.
```

```sql
DROP TABLE lakehouse_rotaperfume.gold._score_falso;
```

**3 · O número que o teste 1 vai cobrar**

```sql
SELECT ROUND(auc, 4) AS modelo, ROUND(baseline_auc, 4) AS regra_simples,
       ROUND(ganho_sobre_baseline, 4) AS ganho
FROM lakehouse_rotaperfume.gold.modelo_metricas
ORDER BY _treinado_em DESC LIMIT 1;
```

> *"Guarde esse ganho. O primeiro teste que a gente vai escrever é justamente
> ele: se um dia o modelo parar de ganhar da regra de graça, o job quebra."*

---

**Enquanto ele trabalha, você explica:**

- **Teste de modelo tem duas famílias.** Qualidade (o modelo é bom?) e entrega
  (o score chegou inteiro?). A segunda é a que mais pega problema na vida real:
  um modelo ótimo que não pontuou 300 clientes é um modelo inútil, e ninguém
  recebe erro — o vendedor só nunca mais vê aqueles nomes.
- **O teste do baseline é o que ninguém escreve.** A pergunta certa nunca é "o
  AUC está bom?". É "está melhor do que o que a gente já fazia sem ele?".
  Modelo que empata com um `ORDER BY` custa retreino, custa explicação e custa
  confiança quando erra — e entrega o mesmo.
- **O teste que quebra quando o resultado é bom demais.** AUC ≥ 0,99 em
  previsão de comportamento humano não é talento, é vazamento. Parece
  contraintuitivo quebrar o pipeline porque deu bom; é exatamente por isso que
  funciona.
- **O limiar sai da conversa com o negócio, não da literatura.** 0,70 aqui é
  uma combinação. A pergunta que define o número é: quanto custa uma visita
  perdida contra quanto custa um cliente perdido?

---

## O prompt

```
Continue o bundle em aulas/aula-02-engenharia-de-dados/rotaperfume/.
gold.score_propensao e gold.modelo_metricas estão gravadas.

1. src/ml/14-testes-de-modelo.sql — oito testes no mesmo padrão dos 11 de
   ontem: cada bloco imprime o que calculou e chama raise_error() quando
   estiver errado, interrompendo a tarefa e derrubando o pipeline.

   QUALIDADE (leem a última linha de gold.modelo_metricas)
   1. O modelo ganha do baseline por pelo menos 0,05 de AUC.
      É o teste mais importante: modelo que não ganha da regra de graça é
      complexidade sem retorno.
   2. AUC acima de 0,70 — o mínimo combinado com o negócio.
   3. AUC ABAIXO de 0,99. Bom demais é sintoma de vazamento de dado, não de
      talento. Quebrar aqui é o que impede o modelo de ir para produção
      "prevendo" o que já aconteceu.
   4. A taxa de positivos do rótulo entre 0,15 e 0,85.

   ENTREGA (leem gold.score_propensao)
   5. Todo cliente de features_cliente tem score. Cobertura parcial não dá
      erro: só some gente da lista do vendedor.
   6. O score é uma probabilidade: entre 0 e 1 E com mais de 50 valores
      distintos. Pega o erro de usar predict() no lugar de predict_proba(),
      que devolve a classe e transforma a coluna inteira em zeros e uns.
   7. Nenhuma faixa concentra mais de 90% dos clientes. Um modelo que joga
      todo mundo numa faixa devolveu a lista inteira com outro nome.
   8. A tabela de score tem exatamente uma versão de modelo. Score de duas
      versões diferentes misturado é o começo de uma discussão errada sobre
      "por que o número mudou".

   Ao final, um SELECT de relatório que NÃO quebra: versão, AUC, baseline,
   ganho, feature mais importante, clientes pontuados e muito quentes.

2. Acrescente a tarefa ml_testes ao pipeline, depois de ml_score.

3. Rode:
   databricks bundle validate --target dev --profile projeto-dados-ia
   databricks bundle deploy   --target dev --profile projeto-dados-ia
   databricks bundle run rotaperfume_pipeline --target dev --profile projeto-dados-ia
```

---

## Como verificar a feature

**1 · Os oito passam, e o relatório final aparece**

Abra a tarefa `ml_testes` no DAG. Os oito blocos imprimem `PASSOU`, e a última
query mostra o resumo do modelo.

**2 · Os testes têm dente — quebre de propósito**

Esta é a demonstração da noite. Faça **um** dos três, conforme o tempo:

<details>
<summary><b>a) Quebrar o teste de cobertura (o mais rápido)</b></summary>

```sql
-- tira 200 clientes do score, como um join mal feito faria
DELETE FROM lakehouse_rotaperfume.gold.score_propensao
WHERE cliente_id IN (SELECT cliente_id FROM lakehouse_rotaperfume.gold.score_propensao LIMIT 200);
```

```bash
databricks bundle run rotaperfume_pipeline --target dev --profile projeto-dados-ia
# ml_testes FALHA: "200 clientes com histórico ficaram sem score"
```

Rode o pipeline de novo inteiro para restaurar.
</details>

<details>
<summary><b>b) Quebrar o teste do baseline (o mais didático)</b></summary>

```sql
-- finge um treino em que o modelo empatou com a regra simples
INSERT INTO lakehouse_rotaperfume.gold.modelo_metricas
SELECT modelo, versao, run_id, data_corte, linhas_treino, linhas_teste,
       taxa_positiva, 0.52 AS auc, average_precision, 0.51 AS baseline_auc,
       0.01 AS ganho_sobre_baseline, feature_mais_importante,
       current_timestamp() AS _treinado_em
FROM lakehouse_rotaperfume.gold.modelo_metricas
ORDER BY _treinado_em DESC LIMIT 1;
```

```bash
databricks bundle run rotaperfume_pipeline --target dev --profile projeto-dados-ia
# ml_testes FALHA: "O modelo ganha apenas 0.01 do baseline. Ele não se paga."
```

> *"Repare na mensagem de erro. Ela não diz 'AUC baixo' — diz que o modelo não
> se paga. Mensagem de teste é documentação: ela precisa explicar a DECISÃO que
> alguém tem que tomar às três da manhã."*
</details>

<details>
<summary><b>c) Quebrar o teste do vazamento (o mais surpreendente)</b></summary>

```sql
INSERT INTO lakehouse_rotaperfume.gold.modelo_metricas
SELECT modelo, versao, run_id, data_corte, linhas_treino, linhas_teste,
       taxa_positiva, 0.997 AS auc, average_precision, baseline_auc,
       0.997 - baseline_auc AS ganho_sobre_baseline, feature_mais_importante,
       current_timestamp() AS _treinado_em
FROM lakehouse_rotaperfume.gold.modelo_metricas
ORDER BY _treinado_em DESC LIMIT 1;
```

```bash
databricks bundle run rotaperfume_pipeline --target dev --profile projeto-dados-ia
# ml_testes FALHA: "AUC de 0.997. Bom demais: procure vazamento de dado."
```

> *"O pipeline acabou de recusar um modelo por ser bom demais. Se essa linha
> não existisse, esse modelo iria para produção hoje e quebraria em outubro —
> e ninguém saberia por quê, porque na validação estava lindo."*
</details>

Depois de qualquer um dos três, limpe:

```sql
DELETE FROM lakehouse_rotaperfume.gold.modelo_metricas
WHERE auc IN (0.52, 0.997);
```

**3 · A tabela de métricas é o histórico de qualidade do modelo**

```sql
SELECT versao, ROUND(auc, 4) AS auc, ROUND(baseline_auc, 4) AS baseline,
       ROUND(ganho_sobre_baseline, 4) AS ganho, _treinado_em
FROM lakehouse_rotaperfume.gold.modelo_metricas
ORDER BY _treinado_em DESC;
```

> *"Uma linha por treino. Daqui a seis meses, quando alguém perguntar 'esse
> modelo sempre foi assim?', a resposta está numa query, não na memória de
> quem estava de plantão."*

---

## Se der errado ao vivo

| Sintoma | Causa | Correção em um prompt |
|---|---|---|
| Teste 1 falha logo de cara | O modelo realmente não ganhou do baseline | Ótimo material de aula — é o teste fazendo o trabalho dele. Investigue as features antes de mexer no limiar |
| Teste 6 falha com poucos valores distintos | O score veio de `predict()` e não de `predict_proba()` | *"Troque para mlflow.sklearn.load_model e predict_proba"* |
| Teste 5 falha por 1 cliente | `features_cliente` tem um cliente a mais que o treino | Esperado: o corte de score é 30 dias mais recente. O teste compara score com `features_cliente`, e tem que dar igual |
| `raise_error` não interrompe | Está fora do `CASE WHEN` | `raise_error()` só dispara quando o ramo é avaliado |

**Tempo medido:** ~40 segundos de execução dos oito testes.

---

## O que fica de pé

| Objeto | O quê |
|---|---|
| `src/ml/14-testes-de-modelo.sql` | 8 testes que quebram o pipeline + relatório |
| Job | `rotaperfume_pipeline` com 16 tarefas · **19 testes** que interrompem |
