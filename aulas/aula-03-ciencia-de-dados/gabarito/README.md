# Gabarito — o que os três prompts produzem

**Isto não é o ponto de partida. É o ponto de chegada.**

Estes três arquivos são o resultado de rodar os prompts da noite 3 contra o
workspace, já com as armadilhas resolvidas. Eles ficam aqui, e **não** dentro
de `rotaperfume/src/ml/`, por um motivo: se estivessem no bundle, o Claude Code
encontraria tudo pronto na hora da aula e não haveria nada para construir.

| Arquivo | Do prompt | O que entrega |
|---|---|---|
| [`11-features.py`](11-features.py) | 1 | `gold.features_treino` (2.815 × 20) e `gold.features_cliente` (2.816) |
| [`12-modelo.py`](12-modelo.py) | 2 | o modelo no UC com `@prod`, `score_propensao`, `modelo_metricas`, `calibragem_holdout` |
| [`13-fila.sql`](13-fila.sql) | 3 | `gold.fila_semanal` (200 contatos) e as 4 funções-ferramenta |

## Para que serve

- **Conferir** se o que o Claude Code gerou ao vivo bate com o que funciona
- **Destravar** se algo der errado no meio da aula: copie o arquivo para
  `rotaperfume/src/ml/`, faça o deploy e siga
- **Estudar** antes da aula, para saber onde a explicação vai passar

## Para que NÃO serve

Deixar no bundle antes de começar. `rotaperfume/src/ml/` está no `.gitignore`
justamente para que a pasta nasça vazia toda vez.
