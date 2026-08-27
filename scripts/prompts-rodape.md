---

## Fim da noite 4 · o que existe agora

```sql
SELECT 'noite 1 · o dado'      AS etapa, COUNT(*) AS numero FROM lakehouse_rotaperfume.bronze.pedidos
UNION ALL SELECT 'noite 2 · o pipeline',  COUNT(*) FROM lakehouse_rotaperfume.gold.fato_vendas
UNION ALL SELECT 'noite 3 · a decisão',   COUNT(*) FROM lakehouse_rotaperfume.gold.fila_semanal
UNION ALL SELECT 'noite 4 · o retorno',   COUNT(*) FROM lakehouse_rotaperfume.gold.retorno_ligacao;
-- 28.729 · 191.080 · 200 · e a última só tem número depois que alguém clica
```

Doze prompts, doze deploys. Um catálogo, um pipeline de 16 tarefas, um modelo
no Unity Catalog, dois Genie spaces e um Databricks App que escreve de volta.

## Para refazer do zero

Cada noite tem o próprio script de limpeza, e eles são **independentes**: dá
para apagar só a noite 4 e refazer os prompts 10 a 12 sem tocar no resto.

```bash
bash aulas/aula-04-app-e-genie/prd/99-limpar-aula-04.sh   <perfil> --apagar   # prompts 10–12
bash aulas/aula-03-ciencia-de-dados/prd/99-limpar-aula-03.sh <perfil> --apagar # prompts 7–9
bash aulas/aula-02-engenharia-de-dados/prd/00-reset.sh    <perfil> --apagar   # tudo
```

Sem `--apagar`, os três apenas **mostram** o que fariam.
