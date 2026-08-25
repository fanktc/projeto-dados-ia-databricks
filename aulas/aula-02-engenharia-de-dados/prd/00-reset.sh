#!/usr/bin/env bash
# Setup 00 · APAGA TUDO da noite 2 e devolve o ambiente ao zero.
#
# Existe por um motivo só: os seis prompts precisam funcionar a partir do nada.
# Se você não consegue apagar, você não consegue provar que reconstrói.
#
# Uso:  bash prd/00-reset.sh <profile> [--sim]
#       Sem --sim ele só MOSTRA o que faria.
#
# O que apaga:
#   1. o deployment do bundle no workspace (jobs, dashboards, Genie space)
#   2. o catálogo lakehouse_rotaperfume INTEIRO, com bronze, silver e gold
#   3. a pasta local rotaperfume/, com todo o código dos seis prompts
set -euo pipefail

PROFILE="${1:?uso: bash prd/00-reset.sh <profile> [--sim]}"
CONFIRMA="${2:-}"
CATALOGO="${CATALOGO:-lakehouse_rotaperfume}"

AULA="$(cd "$(dirname "$0")/.." && pwd)"
BUNDLE="$AULA/rotaperfume"

echo "profile:   $PROFILE"
echo "catálogo:  $CATALOGO  (DROP ... CASCADE)"
echo "bundle:    $BUNDLE    (destroy + rm -rf)"
echo

if [ "$CONFIRMA" != "--sim" ]; then
  echo "Simulação. Nada foi apagado."
  echo "Para apagar de verdade:  bash prd/00-reset.sh $PROFILE --sim"
  exit 0
fi

# 1. o que o bundle criou, o bundle desfaz
if [ -f "$BUNDLE/databricks.yml" ]; then
  echo "→ destruindo o deployment do bundle..."
  (cd "$BUNDLE" && databricks bundle destroy --target dev --auto-approve --profile "$PROFILE") || true
fi

# 2. o que sobrou do catálogo — inclusive o que a noite 1 criou clicando
echo "→ dropando o catálogo $CATALOGO..."
echo "DROP CATALOG IF EXISTS $CATALOGO CASCADE" \
  | databricks experimental aitools tools query --profile "$PROFILE" || true

# 3. o código local
echo "→ removendo $BUNDLE..."
rm -rf "$BUNDLE"

echo
echo "Zerado. Agora os seis prompts têm que reconstruir tudo do nada."
echo "Comece por prd/prompt-01-raw.md."
