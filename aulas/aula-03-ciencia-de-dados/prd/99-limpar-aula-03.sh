#!/usr/bin/env bash
# Limpa SÓ a noite 3 e devolve o ambiente ao fim da noite 2.
#
# A noite 2 continua de pé: catálogo, bronze, silver, gold, dashboard e Genie.
# Some apenas o que os três prompts de hoje criaram — para você poder rodar os
# três de novo, do zero, quantas vezes quiser.
#
# Uso:  bash prd/99-limpar-aula-03.sh <profile> [--apagar]
#       Sem --apagar ele só MOSTRA o que faria.
#
# O que apaga:
#   1. as quatro tabelas de ML da gold
#   2. as quatro funções-ferramenta da gold
#   3. o modelo registrado no Unity Catalog, com todas as versões
#   4. o experimento do MLflow
#   5. os arquivos locais src/ml/ e as três tarefas do pipeline.job.yml
#   6. redeploy do bundle, para o job voltar a ter 12 tarefas
set -euo pipefail

PROFILE="${1:?uso: bash prd/99-limpar-aula-03.sh <profile> [--apagar]}"
CONFIRMA="${2:-}"
CATALOGO="${CATALOGO:-lakehouse_rotaperfume}"

AULA="$(cd "$(dirname "$0")/.." && pwd)"
BUNDLE="$(cd "$AULA/../aula-02-engenharia-de-dados/rotaperfume" && pwd)"

TABELAS=(features_treino features_cliente score_propensao fila_semanal
         modelo_metricas calibragem_holdout)
FUNCOES=(priorizar_carteira contexto_cliente sugerir_produtos checar_disponibilidade)
MODELO="$CATALOGO.gold.propensao_compra"

echo "profile:   $PROFILE"
echo "catálogo:  $CATALOGO   (a noite 2 NÃO é tocada)"
echo "tabelas:   ${TABELAS[*]}"
echo "funções:   ${FUNCOES[*]}"
echo "modelo:    $MODELO"
echo "bundle:    $BUNDLE"
echo

if [ "$CONFIRMA" != "--apagar" ]; then
  echo "Simulação. Nada foi apagado."
  echo "Para apagar de verdade:  bash prd/99-limpar-aula-03.sh $PROFILE --apagar"
  exit 0
fi

sql() { echo "$1" | databricks experimental aitools tools query --profile "$PROFILE" || true; }

echo "→ dropando as tabelas de ML..."
for t in "${TABELAS[@]}"; do sql "DROP TABLE IF EXISTS $CATALOGO.gold.$t"; done

echo "→ dropando as funções-ferramenta..."
for f in "${FUNCOES[@]}"; do sql "DROP FUNCTION IF EXISTS $CATALOGO.gold.$f"; done

echo "→ apagando o modelo registrado (todas as versões)..."
databricks registered-models delete "$MODELO" --profile "$PROFILE" 2>/dev/null || \
  echo "   (modelo não existia — segue)"

echo "→ apagando o experimento do MLflow..."
EXP="/Users/$(databricks current-user me --profile "$PROFILE" -o json | python3 -c 'import sys,json;print(json.load(sys.stdin)["userName"])')/rotaperfume"
databricks workspace delete "$EXP" --recursive --profile "$PROFILE" 2>/dev/null || \
  echo "   (pasta $EXP não existia — segue)"

echo "→ removendo o código local da noite 3..."
rm -rf "$BUNDLE/src/ml"

echo
echo "Falta um passo, e ele é seu:"
echo "  1. tire as tarefas ml_features, ml_modelo e ml_fila de"
echo "     $BUNDLE/resources/pipeline.job.yml"
echo "  2. cd $BUNDLE && databricks bundle deploy --target dev --profile $PROFILE"
echo
echo "Aí o job volta para 12 tarefas e os três prompts de hoje têm que"
echo "reconstruir tudo do nada."
