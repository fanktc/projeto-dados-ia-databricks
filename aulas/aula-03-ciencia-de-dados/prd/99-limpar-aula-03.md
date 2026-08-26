# Limpar a noite 3 — para recriar tudo do zero

**Use antes de ensaiar, e de novo antes de subir ao vivo.** Se você não
consegue apagar, você não consegue provar que reconstrói.

Isto apaga **só a noite 3**. A noite 2 fica intacta: catálogo, bronze, silver,
gold, dashboard e Genie continuam de pé, e o job volta a ter 12 tarefas.

---

## O caminho rápido

```bash
bash aulas/aula-03-ciencia-de-dados/prd/99-limpar-aula-03.sh <perfil>            # simula
bash aulas/aula-03-ciencia-de-dados/prd/99-limpar-aula-03.sh <perfil> --apagar   # apaga
```

**O script não mexe no `pipeline.job.yml`, e esse é o passo que falta.** Ele
apaga o que está no workspace e a pasta `src/ml/`, mas as tarefas de ML
continuam declaradas no YAML apontando para arquivos que não existem mais — e
aí o próximo `bundle deploy` falha.

Hoje são **oito** tarefas a remover: `ml_features`, `ml_modelo`, `ml_fila` (a
versão atual) e `ml_treino`, `ml_promocao`, `ml_score`, `ml_testes`,
`ml_carteira_do_dia` (a anterior). O script lista todas ao terminar.

> **Se você não quiser fazer isso à mão, use o prompt abaixo em vez do
> script** — ele cuida do YAML e do redeploy também.

---

## O prompt

```
Apague tudo que a noite 3 criou no bundle
aulas/aula-02-engenharia-de-dados/rotaperfume/, e SÓ o que ela criou.
A noite 2 tem que continuar funcionando: não toque em bronze, silver, nas
tabelas gold que não são de ML, no dashboard nem no Genie Space.

Use o profile <perfil>.

1. No catálogo lakehouse_rotaperfume, na gold. Apague o que QUALQUER versão
   da noite 3 possa ter criado — o workspace pode estar na versão de três
   prompts ou na anterior, de seis:

     DROP TABLE    features_treino, features_cliente, score_propensao,
                   fila_semanal, modelo_metricas, calibragem_holdout,
                   modelo_importancia, modelo_promocoes, modelo_validacao
     DROP VIEW     carteira_do_dia, oportunidade_por_faixa, receita_em_risco
     DROP FUNCTION priorizar_carteira, contexto_cliente, sugerir_produtos,
                   checar_disponibilidade

   Todos com IF EXISTS — isto vai rodar de novo em cima do que já não existe.
   DROP TABLE não derruba view: as três precisam de DROP VIEW mesmo.

2. Apague o modelo registrado lakehouse_rotaperfume.gold.propensao_compra,
   com todas as versões e aliases:
     databricks registered-models delete <nome> --profile <perfil>

3. Apague o experimento do MLflow criado no treino, e a pasta que o continha.

4. Remova a pasta local src/ml/ inteira.

5. Em resources/pipeline.job.yml, remova TODAS as tarefas de ML — as da versão
   atual (ml_features, ml_modelo, ml_fila) e as da anterior (ml_treino,
   ml_promocao, ml_score, ml_testes, ml_carteira_do_dia) — e qualquer
   depends_on que aponte para elas. O job tem que voltar a terminar em
   auditoria_de_metadado, com 12 tarefas.

6. databricks bundle validate e depois deploy no target dev.

No fim, confirme na tela:
  - SHOW TABLES IN lakehouse_rotaperfume.gold  não lista nenhuma tabela de ML
  - SHOW MODELS IN lakehouse_rotaperfume.gold  não lista nada
  - o job aparece com 12 tarefas
  - gold.fato_vendas continua respondendo
```

---

## Como conferir que sobrou só o que devia

```sql
-- não pode voltar nada
SHOW TABLES  IN lakehouse_rotaperfume.gold LIKE '*features*';
SHOW TABLES  IN lakehouse_rotaperfume.gold LIKE '*score*';
SHOW TABLES  IN lakehouse_rotaperfume.gold LIKE '*fila*';
SHOW TABLES  IN lakehouse_rotaperfume.gold LIKE '*modelo*';
SHOW VIEWS   IN lakehouse_rotaperfume.gold LIKE '*carteira*';
SHOW MODELS  IN lakehouse_rotaperfume.gold;

-- e a noite 2 tem que continuar em pé
SELECT COUNT(*) FROM lakehouse_rotaperfume.gold.fato_vendas;
SELECT COUNT(*) FROM lakehouse_rotaperfume.gold.dim_cliente;
```

---

## Se quiser apagar tudo, e não só a noite 3

Aí é o reset da noite 2, que derruba o catálogo inteiro e a pasta do bundle:

```bash
bash aulas/aula-02-engenharia-de-dados/prd/00-reset.sh <perfil> --apagar
```

Depois disso são **nove prompts** para reconstruir: os seis da noite 2 e os
três de hoje.
