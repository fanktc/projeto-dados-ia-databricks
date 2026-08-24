#!/usr/bin/env python3
"""Executa um arquivo .sql no Databricks, uma statement por vez.

Com `--sufixo`, reescreve os schemas na hora de executar: `bronze` vira
`bronze_aovivo`, e o volume acompanha. Serve para dar a aula sem sobrescrever
o catálogo que já está pronto — os arquivos .sql seguem limpos, sem sufixo
nenhum escrito neles.

A CLI (`databricks experimental aitools tools query`) aceita só uma statement
por chamada. Este runner divide o arquivo em `;` (respeitando aspas e
comentários) e dispara uma chamada por statement.

Uso:  python3 scripts/run_sql.py aulas/aula-01-databricks-sql/00-setup-catalogo.sql [--profile projeto-dados-ia] [--quiet]
"""
import argparse, re, subprocess, sys

SCHEMAS = ("bronze", "silver", "gold")


def aplicar_sufixo(sql: str, sufixo: str) -> str:
    """Acrescenta o sufixo aos schemas, em tabelas e no caminho do volume."""
    if not sufixo:
        return sql
    for schema in SCHEMAS:
        # catalogo.schema.tabela e catalogo.schema (CREATE SCHEMA)
        sql = re.sub(rf"(\w+)\.{schema}\b", rf"\1.{schema}{sufixo}", sql)
        # /Volumes/catalogo/schema/...
        sql = re.sub(rf"(/Volumes/\w+)/{schema}/", rf"\1/{schema}{sufixo}/", sql)
    return sql


def dividir(sql: str) -> list[str]:
    """Divide em statements, ignorando ';' dentro de string ou comentário."""
    stmts, atual, i = [], [], 0
    aspas = False
    while i < len(sql):
        c = sql[i]
        if not aspas and sql.startswith("--", i):          # comentário de linha
            fim = sql.find("\n", i)
            fim = len(sql) if fim == -1 else fim
            atual.append(sql[i:fim])
            i = fim
            continue
        if c == "'":
            aspas = not aspas
        if c == ";" and not aspas:
            stmts.append("".join(atual))
            atual, i = [], i + 1
            continue
        atual.append(c)
        i += 1
    stmts.append("".join(atual))
    # descarta o que sobrou só com comentário ou espaço
    return [s.strip() for s in stmts
            if any(l.strip() and not l.strip().startswith("--") for l in s.splitlines())]


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("arquivo")
    ap.add_argument("--profile", default="projeto-dados-ia")
    ap.add_argument("--quiet", action="store_true", help="não imprime o resultado, só o status")
    ap.add_argument("--sufixo", default="",
                    help="sufixo dos schemas (ex.: _aovivo). Reescreve bronze -> "
                         "bronze_aovivo em tabelas e no caminho do volume")
    ap.add_argument("--continuar", action="store_true",
                    help="segue para a próxima statement mesmo se uma falhar "
                         "(alguns arquivos da aula têm query que quebra de propósito)")
    args = ap.parse_args()

    stmts = dividir(aplicar_sufixo(open(args.arquivo, encoding="utf-8").read(),
                                   args.sufixo))
    alvo = f" · schemas com sufixo '{args.sufixo}'" if args.sufixo else ""
    print(f"{args.arquivo}: {len(stmts)} statement(s){alvo}\n")

    for n, stmt in enumerate(stmts, 1):
        # primeira linha não-comentário, só para identificar a statement no log
        titulo = next((l.strip() for l in stmt.splitlines()
                       if l.strip() and not l.strip().startswith("--")), "")[:70]
        print(f"[{n}/{len(stmts)}] {titulo}")
        # via stdin: um statement que comece com "--" (comentário) seria
        # confundido com uma flag se fosse passado como argumento.
        r = subprocess.run(
            ["databricks", "experimental", "aitools", "tools", "query",
             "--profile", args.profile],
            input=stmt, capture_output=True, text=True,
        )
        if r.returncode != 0:
            print(f"  FALHOU\n{r.stderr.strip()}\n{r.stdout.strip()}")
            if not args.continuar:
                return 1
            print()
            continue
        saida = r.stdout.strip()
        if not args.quiet and saida and saida != "[]":
            print("\n".join("  " + l for l in saida.splitlines()))
        print("  ok\n")
    return 0


if __name__ == "__main__":
    sys.exit(main())
