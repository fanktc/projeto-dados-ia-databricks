#!/usr/bin/env bash
# Roda UMA tarefa do pipeline, em vez do job inteiro.
#
# Por que existe: `bundle run rotaperfume_pipeline` executa as 13 tarefas, e
# cada tarefa serverless paga o seu tempo de partida. São ~3m30 para ver o
# resultado de uma tarefa que você acabou de escrever. Rodando só ela: ~35s.
#
# Ao vivo isso é a diferença entre a sala esperando três minutos e meio a cada
# tentativa, ou trinta segundos.
#
# O job completo continua valendo — mas uma vez, no fim, quando a tarefa já
# funciona e você quer mostrar o DAG inteiro verde.
#
# Uso:  bash scripts/rodar-tarefa.sh <profile> <tarefa>
#       bash scripts/rodar-tarefa.sh projeto-dados-ia ml_features
set -euo pipefail

PROFILE="${1:?uso: bash scripts/rodar-tarefa.sh <profile> <tarefa>}"
TAREFA="${2:?uso: bash scripts/rodar-tarefa.sh <profile> <tarefa>}"

JOB_ID=$(databricks jobs list --profile "$PROFILE" -o json \
  | python3 -c "import sys,json;print([j['job_id'] for j in json.load(sys.stdin) if 'rotaperfume' in j['settings']['name']][0])")

echo "job $JOB_ID · rodando só a tarefa $TAREFA"
echo

# A CLI não tem flag para isto, mas a API de jobs aceita o campo `only`.
databricks jobs run-now \
  --json "{\"job_id\": $JOB_ID, \"only\": [\"$TAREFA\"]}" \
  --profile "$PROFILE" -o json \
  | python3 -c "
import sys, json
r = json.load(sys.stdin)
estado = r.get('state', {})
print('resultado:', estado.get('result_state', estado.get('life_cycle_state', '?')))
for t in r.get('tasks', []):
    s = t.get('state', {})
    print(f\"  {t['task_key']}: {s.get('result_state', s.get('life_cycle_state','?'))}\")
    if s.get('state_message'): print('   ', s['state_message'][:200])
"
