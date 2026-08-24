"""Entrypoints do job da Rota do Perfume.

Dois comandos, um por tarefa do job:

    bronze     ingere os 10 CSVs do volume para tabelas Delta
    verificar  confere os números-âncora e a sujeira preservada

Os dois recebem --catalog e --schema, que o job passa a partir das variáveis
do bundle. Nada de catálogo hardcoded: o mesmo código roda em dev e em prod.
"""

import argparse
import sys

from databricks.sdk.runtime import spark

from perfumesarabe import ingestao, verificacao


def _args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--catalog", required=True)
    parser.add_argument("--schema", required=True)
    return parser.parse_args()


def bronze() -> None:
    args = _args()
    print(f"Ingerindo de {ingestao.caminho_volume(args.catalog, args.schema)}\n")
    contagens = ingestao.ingerir_todas(spark, args.catalog, args.schema)
    print(f"\n{len(contagens)} tabelas, {sum(contagens.values()):,} linhas.")

    divergentes = {
        t: n for t, n in contagens.items() if n != ingestao.LINHAS_ESPERADAS[t]
    }
    if divergentes:
        # Volumetria errada é queda silenciosa de ingestão: o job "passa" e o
        # dashboard mostra menos venda. Melhor quebrar aqui.
        sys.exit(f"Volumetria inesperada: {divergentes}")


def verificar() -> None:
    args = _args()
    print(f"Verificando {args.catalog}.{args.schema}\n")
    falhas = verificacao.verificar(spark, args.catalog, args.schema)
    if falhas:
        sys.exit("\n".join(["Verificação falhou:", *falhas]))
    print("\nTodos os testes passaram.")


# Mantido para `uv run main`, que o template expõe.
def main() -> None:
    bronze()


if __name__ == "__main__":
    main()
