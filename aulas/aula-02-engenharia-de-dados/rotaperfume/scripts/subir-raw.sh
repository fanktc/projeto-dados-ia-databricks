#!/usr/bin/env bash
# Sobe os CSVs de ERP e CRM para o Volume raw do Unity Catalog.
#
# Uso:  bash scripts/subir-raw.sh <profile>
#
# Duas coisas que pegam quem faz pela primeira vez:
#   1. `databricks fs cp` exige o esquema `dbfs:` no destino, MESMO sendo um
#      Volume do UC. Sem ele, o comando reclama de caminho inválido.
#   2. O dataset é gerado com seed fixa (42): todo aluno sobe exatamente o
#      mesmo dado, então todo aluno chega no mesmo número.
set -euo pipefail

PROFILE="${1:?informe o profile: bash scripts/subir-raw.sh <profile>}"
CATALOGO="${2:-lakehouse_rotaperfume}"

RAIZ="$(cd "$(dirname "$0")/../../../.." && pwd)"   # raiz do repositório
DADOS="$RAIZ/dados"
DESTINO="dbfs:/Volumes/$CATALOGO/bronze/raw"

if [ ! -d "$DADOS/erp" ]; then
  echo "dados/ não existe — gerando com seed 42..."
  python3 "$RAIZ/material/gerar_dataset.py" --saida "$DADOS" --seed 42
fi

for sistema in erp crm; do
  echo "→ $sistema"
  databricks fs cp --recursive --overwrite "$DADOS/$sistema" "$DESTINO/$sistema" --profile "$PROFILE"
done

echo
databricks fs ls "$DESTINO/erp" --profile "$PROFILE"
databricks fs ls "$DESTINO/crm" --profile "$PROFILE"
