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
#   1. as tabelas de ML da gold — das DUAS versões da noite 3
#   2. as views de decisão (DROP TABLE não derruba view)
#   3. as funções-ferramenta da gold
#   4. o modelo registrado no Unity Catalog, com todas as versões
#   5. o experimento do MLflow
#   6. os arquivos locais src/ml/ e as tarefas de ML do pipeline.job.yml
#   7. redeploy do bundle, para o job voltar a ter 12 tarefas
set -euo pipefail

PROFILE="${1:?uso: bash prd/99-limpar-aula-03.sh <profile> [--apagar]}"
CONFIRMA="${2:-}"
CATALOGO="${CATALOGO:-lakehouse_rotaperfume}"

AULA="$(cd "$(dirname "$0")/.." && pwd)"
BUNDLE="$(cd "$AULA/../aula-02-engenharia-de-dados/rotaperfume" && pwd)"

# Cobre as DUAS versões da noite 3: a de 3 prompts (atual) e a de 6 prompts
# (anterior), porque o workspace pode estar em qualquer uma das duas.
TABELAS=(features_treino features_cliente score_propensao fila_semanal
         modelo_metricas calibragem_holdout
         modelo_importancia modelo_promocoes modelo_validacao)
VIEWS=(carteira_do_dia oportunidade_por_faixa receita_em_risco)
FUNCOES=(priorizar_carteira contexto_cliente sugerir_produtos checar_disponibilidade)
MODELO="$CATALOGO.gold.propensao_compra"
TAREFAS=(ml_features ml_modelo ml_fila
         ml_treino ml_promocao ml_score ml_testes ml_carteira_do_dia)

echo "profile:   $PROFILE"
echo "catálogo:  $CATALOGO   (a noite 2 NÃO é tocada)"
echo "tabelas:   ${TABELAS[*]}"
echo "views:     ${VIEWS[*]}"
echo "funções:   ${FUNCOES[*]}"
echo "tarefas:   ${TAREFAS[*]}"
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

echo "→ dropando as views de decisão..."
for v in "${VIEWS[@]}"; do sql "DROP VIEW IF EXISTS $CATALOGO.gold.$v"; done

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
echo "  1. tire TODAS as tarefas de ML de"
echo "     $BUNDLE/resources/pipeline.job.yml"
echo "     (${TAREFAS[*]})"
echo "  2. cd $BUNDLE && databricks bundle deploy --target dev --profile $PROFILE"
echo
echo "Aí o job volta para 12 tarefas e os três prompts de hoje têm que"
echo "reconstruir tudo do nada."
