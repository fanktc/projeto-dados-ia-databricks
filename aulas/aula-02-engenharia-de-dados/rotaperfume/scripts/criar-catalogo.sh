#!/usr/bin/env bash
# Cria o catálogo da Rota do Perfume. Roda UMA vez, antes do primeiro deploy.
#
# Por que não está no bundle: no Databricks Free Edition o Default Storage está
# ligado, e nessa configuração a API do Unity Catalog recusa criar catálogo —
# ela exige um MANAGED LOCATION que a conta gratuita não tem para oferecer:
#
#   Error: Metastore storage root URL does not exist.
#          Default Storage is enabled in your account. (400 INVALID_STATE)
#
# O comando SQL, esse funciona. Então o catálogo nasce aqui e todo o resto —
# schemas, volume, jobs, dashboard, Genie — nasce no bundle.
#
# Uso:  bash scripts/criar-catalogo.sh <profile>
set -euo pipefail

PROFILE="${1:?uso: bash scripts/criar-catalogo.sh <profile>}"
CATALOGO="${2:-lakehouse_rotaperfume}"

echo "CREATE CATALOG IF NOT EXISTS $CATALOGO
      COMMENT 'Imersão Jornada de Dados — distribuidora B2B Rota do Perfume.'" \
  | databricks experimental aitools tools query --profile "$PROFILE"

echo "catálogo $CATALOGO pronto."
