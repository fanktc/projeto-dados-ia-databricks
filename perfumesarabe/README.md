# perfumesarabe — deploy da Rota do Perfume

Bundle (DABs) que leva a ingestão bronze para o workspace como job agendado.

* `src/perfumesarabe/ingestao.py`: lê os 10 CSVs do volume e grava Delta, tudo texto.
* `src/perfumesarabe/verificacao.py`: os números-âncora e a sujeira que a bronze deve preservar.
* `src/perfumesarabe/main.py`: os entrypoints `bronze` e `verificar` usados pelo job.
* `resources/rota_perfume.job.yml`: job de duas tarefas, serverless — ingere e depois verifica.
* `tests/`: contrato dos módulos (sem Databricks) e volumetria da bronze (com workspace).

O catálogo (`rota_perfume`) e o schema (`bronze`) vêm das variáveis do bundle,
não estão no código. O job falha se a volumetria ou os números-âncora divergirem —
melhor quebrar o pipeline do que deixar o dashboard mentir.

```bash
databricks bundle deploy --target dev --profile projeto-dados-ia
databricks bundle run rota_perfume_bronze --target dev --profile projeto-dados-ia
```

Pré-requisito: o volume `/Volumes/rota_perfume/bronze/raw` precisa ter os CSVs.
Veja o README da raiz do repositório.


## Getting started

Choose how you want to work on this project:

(a) Directly in your Databricks workspace, see
    https://docs.databricks.com/dev-tools/bundles/workspace.

(b) Locally with an IDE like Cursor or VS Code, see
    https://docs.databricks.com/dev-tools/vscode-ext.html.

(c) With command line tools, see https://docs.databricks.com/dev-tools/cli/databricks-cli.html

If you're developing with an IDE, dependencies for this project should be installed using uv:

*  Make sure you have the UV package manager installed.
   It's an alternative to tools like pip: https://docs.astral.sh/uv/getting-started/installation/.
*  Run `uv sync --dev` to install the project's dependencies.


# Using this project using the CLI

The Databricks workspace and IDE extensions provide a graphical interface for working
with this project. It's also possible to interact with it directly using the CLI:

1. Authenticate to your Databricks workspace, if you have not done so already:
    ```
    $ databricks configure
    ```

2. To deploy a development copy of this project, type:
    ```
    $ databricks bundle deploy --target dev
    ```
    (Note that "dev" is the default target, so the `--target` parameter
    is optional here.)

    This deploys everything that's defined for this project.
    For example, the default template would deploy a pipeline called
    `[dev yourname] perfumesarabe_etl` to your workspace.
    You can find that resource by opening your workpace and clicking on **Jobs & Pipelines**.

3. Similarly, to deploy a production copy, type:
   ```
   $ databricks bundle deploy --target prod
   ```
   Note the default template has a includes a job that runs the pipeline every day
   (defined in resources/sample_job.job.yml). The schedule
   is paused when deploying in development mode (see
   https://docs.databricks.com/dev-tools/bundles/deployment-modes.html).

4. To run a job or pipeline, use the "run" command:
   ```
   $ databricks bundle run
   ```

5. Finally, to run tests locally, use `pytest`:
   ```
   $ uv run pytest
   ```
