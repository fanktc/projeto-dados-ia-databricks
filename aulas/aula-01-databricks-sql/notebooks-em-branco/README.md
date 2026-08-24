# 📓 Notebooks em branco · para preencher ao vivo

Seis notebooks Databricks com **as perguntas, o contexto e o resultado
esperado** — mas sem as queries. A query é escrita na aula.

A resposta de cada um está no `exemplo-0N-*.sql` correspondente, na pasta
acima. Use como gabarito **depois**, não antes.

| Notebook | Pergunta central | Resposta em |
|---|---|---|
| `01-primeiro-select` | O que existe no catálogo? | `exemplo-01-primeiro-select.sql` |
| `02-order-by-e-distinct` | Qual foi o maior pedido? | `exemplo-02-order-by-e-distinct.sql` |
| `03-where-e-a-sujeira` | Quais pedidos contam como receita? | `exemplo-03-where-e-a-sujeira.sql` |
| `04-receita-no-tempo` | **Qual foi nossa receita?** | `exemplo-04-group-by-receita-no-tempo.sql` |
| `05-melhores-clientes` | **Quem são os melhores clientes?** | `exemplo-05-join-melhores-clientes.sql` |
| `06-margem-marca-e-sazonalidade` | Onde a receita se concentra? | `exemplo-06-margem-marca-e-sazonalidade.sql` |

## Subir para o workspace

```bash
DEST=/Workspace/Users/SEU-EMAIL/imersao-aula-01
databricks workspace mkdirs $DEST --profile SEU-PERFIL

for f in aulas/aula-01-databricks-sql/notebooks-em-branco/*.sql; do
  nome=$(basename "$f" .sql)
  databricks workspace import "$DEST/$nome" --file "$f" \
    --language SQL --format SOURCE --overwrite --profile SEU-PERFIL
done
```

Cada arquivo vira um **notebook SQL** com células separadas. As células de
markdown trazem a pergunta; as células de query estão vazias, esperando.

## Como estão montados

- Cada pergunta vem com uma **dica** dos comandos necessários, sem entregar a
  sintaxe.
- Onde faz sentido, o **resultado esperado** está escrito — assim dá para
  conferir na hora se a query saiu certa.
- Depois de cada bloco importante há um markdown explicando **por que** aquele
  resultado é o que é. Esse texto é o que você fala enquanto a query roda.

## A ordem importa

O notebook `04` tem uma query que **falha de propósito** — as datas em dois
formatos derrubam o `date_trunc`. Rode a versão que quebra **antes** da que
funciona: o erro é o que explica por que a noite 2 existe.

## Pré-requisito

As tabelas bronze precisam existir. Rode antes:

```bash
python3 scripts/run_sql.py aulas/aula-01-databricks-sql/00-setup-catalogo.sql
# suba os CSVs para o volume (veja o README da aula)
python3 scripts/run_sql.py aulas/aula-01-databricks-sql/01-ingestao-bronze.sql
```
