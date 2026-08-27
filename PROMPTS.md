# 🧾 Os 12 prompts, na ordem

Todo o projeto da Rota do Perfume — do CSV cru ao app com o retorno da ligação
— sai de **doze prompts colados em sequência no Claude Code**. Este arquivo é
a sequência inteira, na ordem, para quem quer refazer sozinho.

> **Cada prompt termina com um deploy.** Não junte dois: o valor do formato
> está em ver a coisa subir doze vezes, e em quebrar cedo quando quebra.

| Noite | Prompts | O que existe no fim |
|---|---|---|
| [**2** · engenharia](aulas/aula-02-engenharia-de-dados) | 1 a 6 | catálogo, pipeline de 12 tarefas, dashboard e Genie |
| [**3** · ciência de dados](aulas/aula-03-ciencia-de-dados) | 7 a 9 | modelo no Unity Catalog e a fila dos 200 · 15 tarefas |
| [**4** · apps e agentes](aulas/aula-04-app-e-genie) | 10 a 12 | Genie da direção, o app e o retorno da ligação · 16 tarefas |

---

## Antes do primeiro prompt

```bash
# 1 · o dataset (seed fixa: todo mundo gera exatamente o mesmo dado)
python3 material/gerar_dataset.py --saida ./dados --seed 42

# 2 · autenticar, e ESCOLHER um profile para usar a sequência inteira
databricks auth login
databricks auth profiles

# 3 · o catálogo, que a API do Unity Catalog não cria no Free Edition
cd aulas/aula-02-engenharia-de-dados/rotaperfume
bash scripts/criar-catalogo.sh <perfil>
```

**A pasta `rotaperfume/` do bundle nasce vazia** — é o prompt 1 que a preenche.
Se você já rodou antes, zere com
`bash aulas/aula-02-engenharia-de-dados/prd/00-reset.sh <perfil> --apagar`.

Nos prompts abaixo, **troque `projeto-dados-ia` pelo seu profile**.

---

## Como usar esta página

1. Copie o bloco do prompt (só o que está dentro do ```)
2. Cole no Claude Code, na raiz do repositório
3. Espere o deploy terminar e **confira o número** antes de ir para o próximo
4. O que conferir em cada um está no arquivo linkado no título

Os arquivos linkados têm o que esta página não tem: o que mostrar antes de
colar, o que falar enquanto o Claude Code trabalha, e a tabela **"se der
errado"**. Se for a primeira vez, siga por eles.

---

## Noite 2 · o pipeline nasce

### Prompt 1 · Raw

*os dez arquivos chegaram?* · noite 2 · deploy nº 1 · [texto completo, com o que falar e as armadilhas](aulas/aula-02-engenharia-de-dados/prd/prompt-01-raw.md)

```
Leia aulas/aula-02-engenharia-de-dados/prd/CLAUDE.md antes de começar.

Crie o projeto da noite 2 em aulas/aula-02-engenharia-de-dados/rotaperfume/,
como um Databricks Asset Bundle. Esta é a primeira de seis entregas — as outras
cinco estendem este mesmo bundle, então deixe a estrutura pronta para crescer.

O ambiente está ZERADO: o catálogo não existe. Crie tudo.

CONTEXTO DO WORKSPACE
- profile: projeto-dados-ia   (sempre passe --profile, nunca deixe implícito)
- host: https://dbc-84cd5511-fa25.cloud.databricks.com
- SQL Warehouse: 666be37e3fededf2 (Serverless Starter Warehouse)
- Databricks Free Edition: tudo serverless, nunca configure cluster

1. databricks.yml
   - bundle name: rotaperfume
   - variables: catalog (default lakehouse_rotaperfume) e warehouse_id
     (default 666be37e3fededf2)
   - targets dev (default) e prod
   - include: resources/*.yml

   ARMADILHA IMPORTANTE: NÃO use `mode: development` no target dev. Ele prefixa
   o nome dos recursos com [dev seu_usuario] — inclusive os SCHEMAS do Unity
   Catalog, que virariam dev_fulano_bronze e quebrariam todo o SQL da noite.
   Em vez disso, pause o agendamento explicitamente com
   `presets: { trigger_pause_status: PAUSED }`. Deixe um comentário no YAML
   explicando isso, porque é o tipo de coisa que só se descobre errando.

2. scripts/criar-catalogo.sh
   Cria o catálogo com `CREATE CATALOG IF NOT EXISTS`, via
   `databricks experimental aitools tools query`. Recebe o profile como
   primeiro argumento.

   POR QUE NÃO ESTÁ NO BUNDLE: no Free Edition o Default Storage está ligado,
   e nessa configuração a API do Unity Catalog RECUSA criar catálogo — ela
   exige um MANAGED LOCATION que a conta gratuita não tem:
     Error: Metastore storage root URL does not exist.
            Default Storage is enabled in your account. (400 INVALID_STATE)
   O comando SQL funciona. Deixe esse motivo comentado no script.

3. resources/catalogo.yml — o resto do catálogo como recurso do bundle:
   - schemas: bronze, silver e gold
   - volumes: bronze.raw, do tipo MANAGED
   COMMENT em todos, explicando o papel de cada camada em uma frase.

4. scripts/subir-raw.sh
   Sobe os CSVs de dados/erp e dados/crm (na raiz do repositório) para
   /Volumes/{catalog}/bronze/raw/erp e /crm.
   Use `databricks fs cp --recursive --overwrite` — e lembre que o comando
   exige o esquema `dbfs:` no destino, mesmo sendo um Volume do UC.
   Se dados/ não existir, gere antes com
   `python3 material/gerar_dataset.py --saida ./dados --seed 42`.
   O profile é o primeiro argumento, sem default.

5. src/raw/conferencia.py
   Notebook Python serverless (cabeçalho `# Databricks notebook source`) que faz
   a CONFERÊNCIA DE CHEGADA do raw:
   - lê o parâmetro catalog via dbutils.widgets
   - confere que os 10 arquivos esperados existem no Volume
     (erp: produtos, pedidos, itens_pedido, pagamentos, estoque;
      crm: clientes, vendedores, carteira, oportunidades, visitas)
   - para cada um: tamanho em bytes e número de linhas de dado
   - grava a tabela de controle bronze._raw_arquivos com
     (sistema, arquivo, bytes, linhas, conferido_em) e COMMENT
   - se faltar arquivo ou algum vier vazio, levante exceção e interrompa
   - imprime uma tabela legível ao final

6. resources/pipeline.job.yml
   O job rotaperfume_pipeline, com UMA tarefa: raw_conferencia. Serverless.
   Agendamento diário às 6h, timezone America/Sao_Paulo.
   Este job ganha tarefas nos próximos cinco prompts — escreva isso num
   comentário no topo do YAML, com o desenho de como ele vai ficar.

7. Rode NESTA ORDEM e me mostre a saída de cada passo:
   bash scripts/criar-catalogo.sh projeto-dados-ia
   databricks bundle validate --target dev --profile projeto-dados-ia
   databricks bundle deploy   --target dev --profile projeto-dados-ia
   bash scripts/subir-raw.sh  projeto-dados-ia
   databricks bundle run rotaperfume_pipeline --target dev --profile projeto-dados-ia

A ordem importa duas vezes: o catálogo tem que existir antes do deploy criar os
schemas, e o Volume tem que existir antes de subir arquivo nele.

Não crie a camada bronze ainda. Hoje o dado só chega no Volume.
```

### Prompt 2 · Bronze

*CSV vira Delta, com a sujeira preservada* · noite 2 · deploy nº 2 · [texto completo, com o que falar e as armadilhas](aulas/aula-02-engenharia-de-dados/prd/prompt-02-bronze.md)

```
Continue o bundle em aulas/aula-02-engenharia-de-dados/rotaperfume/.
A camada raw já está no Volume e conferida. Agora crie a bronze.

1. src/bronze/ingestao.py
   Notebook Python serverless (`# Databricks notebook source`) que lê os 10
   CSVs de /Volumes/{catalog}/bronze/raw/{sistema}/{tabela}.csv e grava
   {catalog}.bronze.{tabela} em Delta, modo overwrite.

   REGRAS DA BRONZE — nenhuma limpeza, nenhuma conversão de tipo:
   - leia TUDO como string. Nada de inferSchema.
   - os CSVs são CRLF e têm header. Não use multiLine.
   - adicione só duas colunas: _ingerido_em (timestamp) e _arquivo_origem.
   - escreva a função de ingestão UMA vez e itere sobre a lista das 10 tabelas.
     Não repita bloco por tabela.
   - ao final, imprima uma tabela com o nome e a contagem de linhas de cada uma,
     e compare com o que bronze._raw_arquivos registrou no prompt anterior:
     linhas da tabela = linhas do arquivo menos o header. Se divergir, falhe.

   Adicione COMMENT em cada tabela dizendo de qual sistema de origem ela veio.

2. resources/pipeline.job.yml
   Acrescente a tarefa bronze_ingestao, com depends_on: raw_conferencia.
   A ordem é o conteúdo: se a conferência falhar, a bronze não roda.

3. Rode e me mostre a saída:
   databricks bundle deploy --target dev --profile projeto-dados-ia
   databricks bundle run rotaperfume_pipeline --target dev --profile projeto-dados-ia

CONTAGENS ESPERADAS (do gerador com seed 42 — se divergir, o erro é seu):
  produtos 292 · pedidos 28.729 · itens_pedido 197.724 · pagamentos 27.772
  estoque 8.400 · clientes 3.040 · vendedores 42 · carteira 3.637
  oportunidades 5.979 · visitas 37.936     total: 313.551

Não limpe nada. A sujeira é o conteúdo do próximo prompt.
```

### Prompt 3 · Silver

*a limpeza, com CONSTRAINT declarada* · noite 2 · deploy nº 3 · [texto completo, com o que falar e as armadilhas](aulas/aula-02-engenharia-de-dados/prd/prompt-03-silver.md)

```
Continue o bundle em aulas/aula-02-engenharia-de-dados/rotaperfume/.
A bronze está pronta. Agora a silver: limpar, tipar e declarar o contrato.

Crie os arquivos em src/silver/, um por assunto, em SQL (rodam como sql_task
no warehouse 666be37e3fededf2). Use CREATE OR REPLACE TABLE
lakehouse_rotaperfume.silver.{tabela}.

ATENÇÃO — armadilha já medida neste workspace: ANSI mode está ligado.
to_date() e date_trunc() sobre data malformada ABORTAM a query com
CAST_INVALID_INPUT, não retornam NULL. Use try_to_date() em toda conversão
de data, sempre.

01-clientes.sql
- cnpj vem em três formatos: puro, pontuado e com espaço em volta.
  Normalize para 14 dígitos: trim, depois regexp_replace tirando não-dígito,
  depois lpad com zero à esquerda. Nunca converta CNPJ para número.
- razao_social tem caixa e espaçamento inconsistentes. Padronize com initcap
  e colapse espaço duplo.
- data_cadastro vem em ISO e em dd/MM/yyyy misturados: coalesce de dois
  try_to_date.
- 40 CNPJs têm dois cliente_id. Deduplique com row_number() por cnpj,
  mantendo o cadastro MAIS ANTIGO. Guarde cliente_ids_duplicados (array) para
  rastreabilidade — os pedidos antigos apontam para o id descartado.
- ativo: de 'S'/'N' para boolean.

02-pedidos.sql
- data_pedido nos dois formatos, mesmo tratamento.
- valor_total é texto: CAST para DECIMAL(18,2).
- pedido cancelado tem valor zerado sem flag clara: crie a coluna booleana
  cancelado a partir do status.
- crie valor_liquido: zero quando cancelado, valor_total caso contrário.
- crie ano e mes a partir da data.

03-itens-e-produtos.sql
- produtos: tipos certos, data_lancamento com try_to_date, ativo boolean.
- itens_pedido: quantidade negativa é DEVOLUÇÃO, não erro. Crie devolucao
  (boolean) e quantidade_abs (int). NÃO descarte essas linhas.
- join com produtos para marcar sku_descontinuado quando o produto não está
  mais ativo.

04-crm-e-financeiro.sql
- vendedores, carteira, oportunidades, visitas, pagamentos, estoque.
- carteira: existe vendedor desligado com carteira vigente. Não conserte o
  dado — crie a coluna vigente, que respeita data_fim E data_desligamento, e
  a coluna orfao_vendedor_desligado, que EXPÕE o problema para o gestor.
- oportunidades: as etapas na origem se chamam 'Fechado ganho' e
  'Fechado perdido'. NÃO são 'Ganha' e 'Perdida' — confira antes de escrever
  o CASE, com um SELECT DISTINCT etapa.
- estoque: ruptura como boolean a partir de saldo = 0.

EM TODAS as tabelas silver:
- colunas de auditoria _processado_em e _linhas_origem
- COMMENT na tabela e nas colunas que exigiram decisão de limpeza,
  dizendo o que foi feito e por quê
- depois do CREATE, declare o contrato com
  ALTER TABLE ... ADD CONSTRAINT ... CHECK (...):
    silver.clientes     → length(cnpj) = 14
    silver.clientes     → data_cadastro IS NOT NULL
    silver.pedidos      → data_pedido IS NOT NULL
    silver.pedidos      → NOT cancelado OR valor_liquido = 0
    silver.itens_pedido → quantidade_abs > 0

  ATENÇÃO À QUARTA. A regra intuitiva seria `valor_liquido >= 0`, e ela FALHA:
  135 pedidos têm valor negativo. Não é sujeira — os 135 contêm item devolvido,
  e o saldo do pedido virou negativo. Negócio legítimo. A constraint certa é a
  que está escrita acima: pedido cancelado tem que ter valor ZERO.

  Se uma constraint falhar ao ser adicionada, ela fez o trabalho dela: virou
  uma suposição sua em pergunta, antes de ela virar número no dashboard.

Escreva o caminho COMPLETO das tabelas no SQL (lakehouse_rotaperfume.silver.x).
`sql_task` não substitui identificador por parâmetro, e SQL legível vale mais
numa aula do que IDENTIFIER(:catalog || '.silver.x').

Acrescente ao resources/pipeline.job.yml quatro tarefas sql_task, todas com
depends_on: bronze_ingestao. Elas rodam EM PARALELO entre si — nenhuma
depende da outra, e é o formato que o DAG desenha melhor na tela.

Rode e me mostre a saída:
  databricks bundle deploy --target dev --profile projeto-dados-ia
  databricks bundle run rotaperfume_pipeline --target dev --profile projeto-dados-ia

O QUE PRECISA BATER (medido na noite 1, com seed 42):
  3.443 datas em dd/MM/yyyy convertidas · 1.111 CNPJ pontuados
  223 CNPJ com espaço · 309 CNPJ com zero à esquerda
  40 CNPJ duplicados → 3.000 clientes únicos no final
  2.327 itens de devolução · 957 pedidos cancelados
  76 itens com SKU descontinuado · 441 carteiras de vendedor desligado
```

### Prompt 4 · Gold

*dimensões, fato, marts e os testes que quebram o job* · noite 2 · deploy nº 4 · [texto completo, com o que falar e as armadilhas](aulas/aula-02-engenharia-de-dados/prd/prompt-04-gold.md)

```
Continue o bundle em aulas/aula-02-engenharia-de-dados/rotaperfume/.
A silver está limpa e com contrato. Agora a gold: modelar para consumo.

Crie em src/gold/, em SQL, lendo SÓ da silver — nunca da bronze.

05-dimensoes.sql — quatro dimensões conformadas
  gold.dim_cliente    uma linha por cliente: segmento, cidade, uf, data de
                      cadastro, data do primeiro e do último pedido, total de
                      pedidos, receita acumulada, dias desde a última compra
  gold.dim_produto    uma linha por SKU: marca, categoria, nota olfativa,
                      custo, preço de tabela, data de lançamento, descontinuado
  gold.dim_vendedor   uma linha por vendedor: região, meta mensal, ativo
  gold.dim_calendario uma linha por dia dos 24 meses: ano, mes, nome do mês,
                      trimestre, dia da semana, e a coluna mes_pico_setor
                      (abril, junho e outubro = TRUE)

06-fato-vendas.sql — o contrato, escrito antes do SQL num comentário no topo
  Granularidade: uma linha por ITEM de pedido
  Filtro: exclua pedidos cancelados. NÃO exclua devolução.
  Dimensões: data_pedido, ano, mes, canal, cliente_id, razao_social, segmento,
             cidade, vendedor_id, sku, categoria, marca, nota_olfativa
  Métricas:  quantidade, preco_praticado, receita, custo, margem, devolucao
  custo  = quantidade * custo_unitario do produto
  margem = receita - custo
  Devolução entra com quantidade e receita NEGATIVAS, com a flag devolucao.
  Particione por ano e mes.

  POR QUE A DEVOLUÇÃO FICA DENTRO: se ela ficar de fora, a gold soma
  R$ 103,6 mi e a silver R$ 102,3 mi. R$ 1,26 milhão de diferença entre duas
  camadas do mesmo pipeline. Quem quiser o bruto pede:
    SUM(receita) FILTER (WHERE NOT devolucao)

07-marts.sql — um mart por diretoria, todos sobre o MESMO fato
  gold.mart_vendas_por_vendedor   grão vendedor × mês: receita, margem, meta,
                                  atingimento, clientes atendidos, ticket médio
  gold.mart_produto_performance   grão SKU × mês: receita, margem, margem %,
                                  quantidade, curva ABC por receita acumulada
  gold.mart_financeiro_recebimento grão mês de vencimento: valor a receber,
                                  recebido, atraso médio, custo de taxa

COMMENT em TODAS as tabelas, e em TODAS as colunas de fato_vendas, explicando
o significado de NEGÓCIO, não o técnico. Por exemplo, em margem:
"Receita menos custo do produto. Não considera desconto comercial nem frete."
Nas dimensões, comente as colunas que exigiram decisão (dias_sem_comprar,
mes_pico_setor); cidade e uf se explicam sozinhas.
Isso não é capricho: é o que o Genie lê no prompt 6 para escolher a coluna
certa. Coluna sem comentário é coluna que ele usa errado, com confiança.

08-testes.sql — os 9 testes, cada um levantando exceção com raise_error()
quando falhar, para o job PARAR:
  1. receita da gold = receita da silver = R$ 102.303.828,05 (tolerância 0,01)
     Esse é o teste que mais importa: limpeza NÃO PODE mudar o faturamento.
  2. CNPJ único na silver.clientes (0 duplicados)
  3. nenhuma data_pedido nula na silver.pedidos
  4. receita negativa só onde devolucao = true
  5. volume da gold.fato_vendas entre 140.000 e 250.000 linhas
  6. nenhum pedido_id na gold que não exista na silver.pedidos
  7. nenhum cliente_id na gold que não exista na silver.clientes
  8. mart_produto_performance soma o mesmo que fato_vendas
  9. todo CNPJ com exatamente 14 dígitos
  Cada teste imprime nome, valor calculado, valor esperado e passou/falhou.

Acrescente ao resources/pipeline.job.yml:
  gold_dimensoes   depends_on: as quatro tarefas silver
  gold_fato_vendas depends_on: gold_dimensoes
  gold_marts       depends_on: gold_fato_vendas
  testes           depends_on: gold_marts   ← por último, e obrigatório

Rode e me mostre a saída:
  databricks bundle deploy --target dev --profile projeto-dados-ia
  databricks bundle run rotaperfume_pipeline --target dev --profile projeto-dados-ia

Os 9 testes precisam passar. Se algum falhar, corrija a transformação —
nunca o teste.
```

### Prompt 5 · Dashboard

*a gold vira tela* · noite 2 · deploy nº 5 · [texto completo, com o que falar e as armadilhas](aulas/aula-02-engenharia-de-dados/prd/prompt-05-dashboard.md)

```
Continue o bundle em aulas/aula-02-engenharia-de-dados/rotaperfume/.
A gold está de pé e os 9 testes passam. Agora o dashboard, como código.

Crie resources/dashboard-comercial.lvdash.json e declare-o em
resources/dashboard.dashboard.yml como recurso do tipo `dashboards`, com
file_path, warehouse_id, dataset_catalog e dataset_schema (gold), para que
suba junto no deploy.

REGRAS QUE QUEBRAM O DASHBOARD SE FOREM IGNORADAS:
- As queries do JSON usam nome de tabela PURO: `FROM fato_vendas`. Nunca
  `FROM gold.fato_vendas`. O catálogo e o schema vêm do dataset_catalog e
  dataset_schema — se você prefixar, eles são ignorados.
- Use POUCOS datasets. Widgets que compartilham dataset filtram juntos: clicar
  numa marca filtra a tela inteira. Datasets separados quebram isso. Um dataset
  largo sobre fato_vendas atende KPIs, linha, barras e filtros.
- O `name` em `query.fields` tem que bater EXATAMENTE com o `fieldName` em
  `encodings`, senão o widget mostra "no selected fields to visualize".
- Versão do widget: counter e table são version 2; bar e line são version 3;
  filtros são version 2. Versão errada = widget quebrado.
- Toda página precisa de `"layoutVersion": "GRID_V1"`.

Nada de CAST, nada de try_to_date no SQL dos datasets — se você precisar de um,
a gold está errada e o problema é lá.

VISÕES
- Quatro cartões de KPI: receita total, margem total, número de pedidos,
  ticket médio. Declare as métricas UMA vez, em `columns` no dataset, e use
  MEASURE(`Receita`) nos widgets. É o que garante que nenhuma tela mostre
  receita diferente da outra.
- Linha: receita por mês, os 24 meses.
- Barras: top 10 marcas por receita.
- Barras: margem percentual por categoria, ORDENADA CRESCENTE — é o gráfico
  que mostra que Kit Presente vende muito e ganha pouco.
- Tabela: top 20 clientes por receita, com segmento e cidade.
- Barras: receita por canal.
- Filtros por ano, segmento e cidade, compartilhados entre os widgets, de
  forma que clicar numa marca filtre a tela inteira.

Teste TODAS as queries no warehouse antes de montar o JSON — nenhum widget
pode subir quebrado. Use o tema escuro/claro com `uiSettings.theme` e uma
paleta coerente; o padrão do workspace deixa o dashboard com cara de genérico.

Rode e me mostre a saída:
  databricks bundle validate --profile projeto-dados-ia
  databricks bundle deploy --target dev --profile projeto-dados-ia

Depois me dê o link do dashboard publicado.
```

### Prompt 6 · Genie comercial

*views com nome de negócio e metadado auditado* · noite 2 · deploy nº 6 · [texto completo, com o que falar e as armadilhas](aulas/aula-02-engenharia-de-dados/prd/prompt-06-agentes.md)

```
Continue o bundle em aulas/aula-02-engenharia-de-dados/rotaperfume/.
A gold está modelada, testada e no dashboard. Última entrega: preparar tudo
para consumo por linguagem natural.

1. src/gold/09-metricas-negocio.sql
   Crie views nomeadas como uma pessoa de negócio nomearia — em português, sem
   prefixo técnico:
     gold.receita_mensal        receita, margem e pedidos por mês, com a coluna
                                mes_pico_setor vinda da dim_calendario
     gold.ranking_marcas        marca → receita, margem %, participação %
     gold.margem_por_categoria  categoria → receita, margem, margem %
     gold.clientes_em_risco     sem compra há mais de 90 dias, com quanto
                                compravam por mês antes de sumir
     gold.efeito_lancamento     receita dos SKUs nos 120 dias após o lançamento
                                contra o resto do período
     gold.ruptura_por_marca     % de snapshots em ruptura por marca
   COMMENT em cada view dizendo QUAL PERGUNTA DE NEGÓCIO ela responde — não o
   que ela é. É assim que o Genie escolhe onde procurar.
   Use a forma compacta `CREATE OR REPLACE VIEW nome (col COMMENT '...', ...)`
   para comentar toda coluna sem precisar de um ALTER por coluna.

2. src/gold/10-auditoria-metadado.sql
   Consulte information_schema e QUEBRE com raise_error() se:
   - alguma tabela ou view da gold estiver sem COMMENT
   - alguma coluna de fato_vendas ou das 6 views estiver sem COMMENT
   Ao final, imprima um relatório de cobertura de metadado por objeto — sem
   quebrar. Serve para a conversa com quem vai consumir a gold.
   Metadado faltando é BUG, não pendência de documentação.

3. docs/genie-instrucoes.md
   O texto para colar na configuração do Genie space:
   - Contexto: distribuidora B2B de perfumaria árabe, vende para varejo
   - Glossário: ruptura, carteira, oportunidade, devolução, SKU, segmento,
     atingimento de meta, curva ABC
   - REGRA DE SAZONALIDADE, a mais importante: o pico da distribuidora é o mês
     ANTERIOR à data comemorativa, porque o varejo compra antes. Abril (Dia das
     Mães), junho (Namorados) e outubro (Black Friday) são picos; dezembro e
     janeiro são VALE, e isso é saudável, não é queda.
   - Regra de cálculo de cada métrica: receita, margem, ticket médio,
     atingimento, churn (90 dias sem compra)
   - Aviso: devolução entra com valor negativo. Para o bruto vendido,
     filtre devolucao = false.

4. O Genie space COMO CÓDIGO, dentro do bundle:
   - resources/comercial.geniespace.json com a definição serializada
   - resources/genie.genie_space.yml declarando o recurso `genie_spaces`,
     com title, description, file_path e warehouse_id

   Conteúdo do JSON: as 6 views + fato_vendas + as dimensões como data_sources,
   o texto de instruções acima em `instructions.text_instructions`, pelo menos
   5 perguntas de exemplo em `config.sample_questions`, e 6 pares
   pergunta→SQL em `instructions.example_question_sqls` com SQL já validado.

   QUATRO REGRAS DA API QUE FAZEM O DEPLOY FALHAR SE FOREM IGNORADAS:
   a) `data_sources.tables` tem que estar ORDENADO por `identifier`
   b) `column_configs` de cada tabela ordenado por `column_name`
   c) toda sample_question, text_instruction e example_question_sql precisa de
      um `id` de 32 caracteres hexadecimais minúsculos, sem hífen
   d) essas listas também têm que estar ORDENADAS por `id`

   Gere os ids de forma DETERMINÍSTICA (md5 do conteúdo da pergunta), nunca
   aleatória: assim um redeploy não recria as perguntas nem gera diff no Git
   sem motivo.

   A chave do recurso tem que ser diferente da chave do dashboard — o bundle
   recusa duas chaves iguais mesmo em tipos diferentes.

5. Acrescente ao pipeline as tarefas metricas_de_negocio e
   auditoria_de_metadado, nessa ordem, depois de gold_marts.

6. Rode:
   databricks bundle validate --target dev --profile projeto-dados-ia
   databricks bundle deploy   --target dev --profile projeto-dados-ia
   databricks bundle run rotaperfume_pipeline --target dev --profile projeto-dados-ia

   O pipeline completo tem que rodar verde de ponta a ponta, com 12 tarefas:
   raw → bronze → silver ×4 → dimensões → fato → marts → testes,
   e em paralelo métricas de negócio → auditoria de metadado
```
---

## Fim da noite 2 · confira antes de seguir

```sql
SELECT COUNT(*) AS linhas, ROUND(SUM(receita), 2) AS receita
FROM   lakehouse_rotaperfume.gold.fato_vendas;
-- 191.080 linhas · R$ 102.303.828,05
```

O pipeline tem **12 tarefas** e roda verde de ponta a ponta. Se este número não
bater, não adianta seguir: a noite 3 treina em cima dele.

---

## Noite 3 · o pipeline passa a decidir

### Prompt 7 · Features

*o que descreve um cliente* · noite 3 · deploy nº 7 · [texto completo, com o que falar e as armadilhas](aulas/aula-03-ciencia-de-dados/prd/prompt-01-features.md)

```
Continue o bundle em aulas/aula-02-engenharia-de-dados/rotaperfume/.
A gold está pronta, testada e com metadado auditado. Começa a camada de ML.

Crie src/ml/11-features.py — um notebook Python para serverless.

Defina UMA função montar_features(referencia) que devolve uma linha por
cliente com tudo que se sabia dele ATÉ essa data. Cada fonte é filtrada pela
data dela na primeira linha da leitura, sem exceção:

  gold.fato_vendas        data_pedido   < referencia
  silver.oportunidades    data_abertura < referencia
  silver.visitas          data_visita   < referencia

NÃO leia gold.dim_cliente: dias_sem_comprar, receita_acumulada e
total_pedidos agregam a base INTEIRA, sem corte — usar qualquer uma é
vazamento. Ela só entra no prompt 3, para nome e cidade.

Vinte features, em quatro grupos. Tudo sai de gold.fato_vendas, que já traz
razao_social, canal, categoria e marca — não precisa de join para isso:

  RFM
    recencia_dias        = datediff(referencia, max(data_pedido))
    frequencia_pedidos   = count(distinct pedido_id)
    valor_total          = sum(receita)   -- devolução já entra negativa
    ticket_medio         = valor_total / frequencia_pedidos
    margem_total         = sum(margem)
    margem_percentual    = margem_total / nullif(valor_total, 0)

  Ritmo
    intervalo_medio_dias   = média dos intervalos entre pedidos consecutivos
    desvio_intervalo_dias  = desvio padrão desses mesmos intervalos
                             (calcule os gaps uma vez, com lag() sobre as datas
                              distintas de pedido, e tire média e desvio dali)
    atraso_relativo        = recencia_dias / intervalo_medio_dias,
                             com NULLIF no denominador e teto em 10
    pedidos_ultimos_90d    = pedidos distintos nos 90 dias antes do corte

  CRM
    oportunidades_abertas  = nem ganha nem perdida (as duas são colunas
                             booleanas em silver.oportunidades)
    oportunidades_ganhas   = coluna ganha
    taxa_ganho             = ganhas / nullif(total de oportunidades, 0)
    visitas_90d            = visitas nos 90 dias antes do corte
    conversao_visita       = visitas com gerou_pedido / nullif(visitas, 0)

  Mix
    skus_distintos          = count(distinct sku)
    categorias_distintas    = count(distinct categoria)
    marcas_distintas        = count(distinct marca)
    concentracao_marca_top  = receita da marca top / nullif(valor_total, 0)
    comprou_lancamento      = 1 se comprou algum SKU cuja data_lancamento
                              (de gold.dim_produto) esteja nos 120 dias
                              anteriores ao corte. É o único join necessário.

Grave duas tabelas, chamando a MESMA função duas vezes:

  gold.features_treino   referencia = 2026-08-01, mais o alvo comprou_em_7d
                         = 1 se fez pedido entre 2026-08-01 e 2026-08-07
  gold.features_cliente  referencia = 2026-08-31, sem alvo — é o que será
                         pontuado

As duas gravam uma coluna _referencia com a data de corte usada. Toda soma de
receita ou margem sai da gold como DECIMAL(18,2): use cast para double em
TODAS as features numéricas, senão o registro do modelo quebra depois com
"Object of type Decimal is not JSON serializable".

Cliente sem oportunidade ou sem visita fica com 0, não com NULL — só as
features de ritmo podem ser NULL, para cliente com um pedido só.

Nada de current_date() em lugar nenhum: o "hoje" deste dataset é 2026-08-31.

COMMENT em português NA TABELA — as duas. A auditoria de metadado da noite 2
quebra o job se faltar. Ela não exige comentário nas colunas destas tabelas, e
saveAsTable não grava comment de tabela: rode COMMENT ON TABLE em seguida.

Depois registre a tarefa ml_features em resources/pipeline.job.yml, rodando
depois de testes_de_qualidade — modelo não se treina com dado que ainda não
passou nos testes — e faça o deploy.

DUAS ARMADILHAS MEDIDAS — as duas quebraram na preparação:
  1. F.least() IGNORA nulo e devolve o outro valor: no teto do atraso_relativo,
     os 80 clientes de um pedido só recebem 10 e vão para o TOPO da fila.
     Envolva num when(intervalo_medio_dias IS NOT NULL AND > 0).
  2. Célula que começa com # MAGIC %md é markdown INTEIRA — sem um
     # COMMAND ---------- antes do código, a função não é definida (NameError).
```

### Prompt 8 · Modelo e MLflow

*o baseline que choca* · noite 3 · deploy nº 8 · [texto completo, com o que falar e as armadilhas](aulas/aula-03-ciencia-de-dados/prd/prompt-02-modelo.md)

```
Continue o mesmo bundle. As features estão em gold.features_treino e
gold.features_cliente.

Crie src/ml/12-modelo.py — um notebook Python para serverless. Nesta ordem:

1. BASELINE, antes de treinar qualquer coisa.
   Separe 25% de gold.features_treino como holdout, com random_state=42 e
   estratificado pelo alvo. No holdout, calcule roc_auc_score do alvo contra
   cada regra simples, usada como se fosse o score:
     a) -recencia_dias      ("ligue para quem comprou recentemente")
     b)  valor_total        ("ligue para quem compra mais")
     c)  atraso_relativo    ("ligue para quem está atrasado")
   Imprima os três lado a lado, com 0,5000 (a moeda) na mesma tabela.
   Guarde o melhor deles: é a régua do teste 1.

2. TREINO.
   HistGradientBoostingClassifier do scikit-learn, random_state=42.
   NÃO impute NULL: este algoritmo trata NaN nativamente, e as features de
   ritmo são NULL de propósito para quem tem um pedido só.
   NÃO use XGBoost: ele treina e registra, mas falha ao carregar de volta no
   serverless por conflito com scikit-learn 1.6.1 (__sklearn_tags__), e o erro
   só aparece uma tarefa depois.

3. AS DUAS MÉTRICAS.
   auc          — no holdout
   lift_top200  — pontue TODOS os clientes de features_treino por validação
                  cruzada out-of-fold (StratifiedKFold, 5 folds, shuffle,
                  random_state=42), ordene por score, pegue os 200 primeiros e
                  divida a taxa de compra deles pela taxa base.
                  Out-of-fold, e não só o holdout, porque a fila real é de 200
                  entre 3.000 — no holdout de 700 os 200 primeiros seriam 28%
                  da amostra, e o número sairia otimista.
                  Imprima também acertos_top200 (quantos dos 200 compraram).
                  Essa é a métrica que responde a pergunta do diretor.

4. IMPORTÂNCIA POR PERMUTAÇÃO, no holdout, n_repeats=5. Imprima o top 10.

5. MLFLOW.
   Antes de mlflow.set_experiment, crie a pasta pai com
   WorkspaceClient().workspace.mkdirs(...) — sem isso o erro é
   "BAD_REQUEST: For input string: None" e não menciona pasta nenhuma.
   O serverless tem MLflow 2.22: use log_model(..., artifact_path="modelo"),
   nunca o name= do MLflow 3.
   Registre em lakehouse_rotaperfume.gold.propensao_compra com
   mlflow.set_registry_uri("databricks-uc") e aponte o alias @prod para a
   versão recém-criada.
   Logue params, auc, lift_top200, acertos_top200 e a taxa base.

6. TRÊS TESTES QUE INTERROMPEM A TAREFA (assert, com mensagem em português):
   - o modelo ganha do MELHOR baseline por pelo menos 0,05 de AUC
   - auc < 0,99 — bom demais é vazamento, não competência
   - lift_top200 >= 2,5 — abaixo disso a fila não justifica o projeto

7. SCORE.
   Carregue o modelo com mlflow.sklearn.load_model("models:/...@prod") e use
   predict_proba — NÃO use pyfunc.predict, que devolve a classe e transforma
   a coluna inteira em zeros e uns.
   NÃO use mlflow.pyfunc.spark_udf: não roda no serverless
   (InvalidVersion: '18.x-aarch64-photon-scala2'). Traga para pandas: 3.000
   clientes cabem na memória com folga.
   Pontue com EXATAMENTE as colunas do treino, na mesma ordem, lendo
   modelo.feature_names_in_ — não confie na ordem das colunas da tabela.
   Grave gold.score_propensao com cliente_id (INT), score, a faixa
   (NTILE(4) sobre o score: Fria, Morna, Quente, Muito quente), _referencia e
   a versao do modelo — o número que veio do registro no UC.

8. AS MÉTRICAS TAMBÉM VIRAM TABELA — o Genie não lê MLflow, e daqui a seis
   meses ninguém abre a interface de experimento:

   gold.modelo_metricas     uma linha por treino: versao, auc, lift_top200,
                            acertos_top200, taxa_base, o AUC de cada um dos
                            três baselines, a feature nº 1 e _treinado_em
   gold.calibragem_holdout  faixa, clientes, compraram, taxa_de_compra e
                            score_medio, calculados no holdout — é a prova do
                            slide *Não é acurácia*, e a única que o comercial confere sozinho

COMMENT em português NA TABELA, nas três que este prompt cria. A auditoria da
noite 2 quebra o job se faltar, e saveAsTable não grava comment de tabela:
rode COMMENT ON TABLE em seguida.

Registre a tarefa ml_modelo em resources/pipeline.job.yml, depois de
ml_features, e faça o deploy.

NÃO rode o job inteiro para testar: rode só a tarefa nova, com
bash scripts/rodar-tarefa.sh <perfil> ml_modelo — o job completo leva 3m30 e
a tarefa sozinha 35s.
```

### Prompt 9 · A fila e o agente

*os 200, com motivo* · noite 3 · deploy nº 9 · [texto completo, com o que falar e as armadilhas](aulas/aula-03-ciencia-de-dados/prd/prompt-03-fila-e-agente.md)

```
Continue o mesmo bundle. gold.score_propensao tem os 3.000 clientes com nota.

Crie src/ml/13-fila.sql — um arquivo SQL para rodar como sql_task.

1. A TABELA DA SEMANA: gold.fila_semanal

   As fontes e como juntar:
     gold.score_propensao   cliente_id, score, faixa, versao
     gold.features_cliente  as features, para escrever o motivo
     gold.dim_cliente       razao_social, cidade, uf
     silver.carteira        cliente_id -> vendedor_id.
                            FILTRE por vigente = true, e descarte
                            orfao_vendedor_desligado = true: vendedor
                            desligado não recebe ligação para fazer.
     silver.vendedores      vendedor_id -> nome. A carteira só tem o id.

   A ORDEM DAS OPERAÇÕES IMPORTA, e é o erro mais fácil de cometer aqui:

     1º  junte a carteira e DESCARTE quem não é elegível
         (sem carteira vigente, ou vendedor desligado)
     2º  ORDER BY score DESC LIMIT 200
     3º  ROW_NUMBER() OVER (PARTITION BY vendedor ORDER BY score DESC)

   Se o descarte vier DEPOIS do LIMIT, a fila sai com ~172 linhas em vez de
   200 — seis dos 42 vendedores estão desligados e levam junto os clientes
   deles — e o teste 1 quebra o job. Filtrando antes, sobram 2.393 clientes
   elegíveis e a fila fecha em 200 exatas, distribuídas em ~36 vendedores.
   Não use cota igual por vendedor: a carteira de um é mais quente que a do
   outro, e cota fixa obriga a gastar ligação com cliente frio.

   Colunas: vendedor, ordem, cliente_id, razao_social, cidade, uf, score,
   faixa, ticket_medio, e duas colunas escritas para gente ler:

   motivo — uma frase em português montada com CASE WHEN sobre as features,
   com os números reais do cliente dentro, via FORMAT_NUMBER:
     atraso_relativo > 3   -> 'Compra a cada N dias e está há M sem pedido.
                               Risco de perder para o concorrente.'
     atraso_relativo > 1.5 -> 'Está N vezes mais atrasado que o ritmo dele.'
     comprou_lancamento    -> 'Comprou lançamento recente. Alta chance de
                               repetir.'
     valor_total no topo   -> 'Cliente grande, R$ X no ano. Manter próximo.'
     ELSE                  -> 'Dentro do ritmo. Contato de manutenção.'
   O ELSE é obrigatório: motivo nulo quebra o teste 2.

   sugestao — o SKU mais comprado pelo cliente na marca preferida dele que
   ele NÃO comprou nos últimos 90 dias, com o saldo vindo do snapshot mais
   recente de silver.estoque (a tabela é um snapshot semanal: pegue
   max(data_snapshot) por sku, não a tabela inteira).

2. AS QUATRO FERRAMENTAS, como funções SQL no Unity Catalog, cada uma com
   COMMENT em português dizendo para que serve — é o COMMENT que o agente lê:

   gold.priorizar_carteira(p_vendedor STRING, p_quantos INT)
     RETURNS TABLE — a fatia da fila_semanal daquele vendedor, em ordem
   gold.contexto_cliente(p_cliente_id INT)
     RETURNS TABLE — histórico, ticket médio, marcas preferidas, última compra
   gold.sugerir_produtos(p_cliente_id INT)
     RETURNS TABLE — o que ele compra e parou de comprar nos últimos 90 dias
   gold.checar_disponibilidade(p_sku STRING)
     RETURNS TABLE — saldo e ruptura no snapshot mais recente

   Prefixe TODO parâmetro com p_: parâmetro com o mesmo nome de uma coluna
   fica ambíguo dentro do corpo da função e o CREATE falha.
   cliente_id é INT no catálogo, não BIGINT.

3. TRÊS TESTES QUE QUEBRAM O JOB, no mesmo padrão raise_error() dentro de
   CASE WHEN que a noite 2 usa:
   - a fila tem exatamente 200 linhas
   - nenhuma linha com motivo nulo ou vazio
   - nenhum score fora do intervalo [0, 1]

A ORDEM DOS PASSOS 4 E 5 IMPORTA, e é o erro mais fácil de cometer aqui: o
Genie RECUSA referenciar tabela que ainda não existe. Se o deploy do Genie
acontecer antes de fila_semanal ser criada, ele morre com
"PERMISSION_DENIED ... Table ... does not exist" — e a mensagem não diz que o
problema é ordem. Crie a tabela primeiro (rode a tarefa, ou o SQL pelo
scripts/run_sql.py), e só então faça o deploy com o Genie atualizado.

4. Acrescente uma PÁGINA ao dashboard da noite 2
   (resources/dashboard-comercial.lvdash.json), chamada "Fila da semana":
   um filtro de vendedor e a tabela com ordem, cliente, cidade, nota, faixa,
   motivo e sugestão. É onde o vendedor vai ver a lista — sem isso, os 200
   ficam numa tabela que ele nunca abre.

   NÃO renomeie a chave do recurso do dashboard: trocar a chave faz o bundle
   apagar e recriar, com URL nova.

5. Some gold.fila_semanal e gold.score_propensao ao Genie Space que já existe
   em resources/ (genie.genie_space.yml e o comercial.geniespace.json), com a
   instrução:
   "Use sempre as tabelas e funções deste espaço. Nunca invente número,
    nome de cliente ou quantidade de estoque."

COMMENT em português na TABELA (a auditoria quebra o job sem ele) e TAMBÉM em
todas as colunas de fila_semanal: é o comentário de coluna que o Genie lê para
responder sem inventar. Nas funções, o COMMENT é o que diz ao agente quando
usar cada uma.

Registre a tarefa ml_fila em resources/pipeline.job.yml, depois de ml_modelo,
e faça o deploy.

NÃO rode o job inteiro para testar: rode só a tarefa nova, com
bash scripts/rodar-tarefa.sh <perfil> ml_fila — o job completo leva 3m30 e
a tarefa sozinha 35s.
```
---

## Fim da noite 3 · confira antes de seguir

```sql
SELECT COUNT(*)                            AS contatos,          -- 200
       COUNT(DISTINCT vendedor)            AS vendedores,        -- 35
       ROUND(SUM(score * ticket_medio), 2) AS receita_esperada   -- 582.799,50
FROM   lakehouse_rotaperfume.gold.fila_semanal;
```

O pipeline tem **15 tarefas**. O modelo `gold.propensao_compra` está no
catálogo com alias `@prod`, e `lift_top200` é **4,25×**.

---

## Noite 4 · o projeto ganha uma URL

### Prompt 10 · Genie da direção

*o produto que se pergunta* · noite 4 · deploy nº 10 · [texto completo, com o que falar e as armadilhas](aulas/aula-04-app-e-genie/prd/prompt-01-genie.md)

```
Continue o bundle em aulas/aula-02-engenharia-de-dados/rotaperfume/.
A noite 3 deixou gold.fila_semanal com 200 contatos e gold.score_propensao
com a nota de todos os clientes. Hoje eu quero duas coisas: a tabela onde o
time registra o que aconteceu depois da ligação, e um Genie space feito para
a direção.

1. src/gold/11-retorno-ligacao.sql — a tabela do caminho de volta

   CREATE TABLE IF NOT EXISTS lakehouse_rotaperfume.gold.retorno_ligacao com:
     cliente_id      INT
     vendedor        STRING
     status          STRING     vendeu | vai_pensar | sem_interesse | nao_atendeu
     comentario      STRING     texto livre do vendedor
     registrado_em   TIMESTAMP
     registrado_por  STRING     e-mail de quem estava logado
     _referencia     DATE       a semana da fila

   IF NOT EXISTS, e não CREATE OR REPLACE: é a ÚNICA tabela do projeto cujo
   dado não vem do pipeline. Um redeploy não pode apagar o que o time
   respondeu.

   COMMENT em toda coluna e na tabela — a auditoria de metadado da noite 2
   quebra o job se faltar, e é o COMMENT que o Genie lê para escolher coluna.

   Acrescente ao pipeline a tarefa gold_retorno_ligacao, depois de gold_marts.
   O job vai de 15 para 16 tarefas.

2. resources/direcao.geniespace.json + resources/genie-direcao.genie_space.yml

   Um SEGUNDO Genie space, chamado "Rota do Perfume · Direção". Não altere o
   genie_comercial que já existe — a chave dele não pode mudar.

   Fontes, e só estas sete:
     gold.fila_semanal      o assunto principal
     gold.score_propensao   a nota de todos, para o cliente fora da fila
     gold.modelo_metricas   lift_top200, acertos_top200, taxa_base
     gold.retorno_ligacao   o que aconteceu depois
     gold.clientes_em_risco, gold.ranking_marcas, gold.receita_mensal

   As instruções, em português, cobrindo:
   - quem pergunta: a direção comercial, que não escreve SQL e decide ligação
   - o que é score (0 a 1, chance de comprar em 7 dias), faixa, ordem, motivo
   - por que a fila é GLOBAL e não cota por vendedor: quem tem carteira quente
     recebe mais contatos, e isso está certo
   - receita esperada da fila = SUM(score * ticket_medio), e é ESTIMATIVA,
     nunca receita realizada
   - a métrica da direção é lift_top200. NUNCA cite AUC para responder
     pergunta de negócio: AUC é métrica de quem treina
   - retorno_ligacao começa VAZIA. Se a resposta for zero, diga que ninguém
     registrou retorno ainda — não invente número, e não use a fila como se
     fosse retorno
   - um cliente pode ter mais de um retorno: para o estado atual, use o mais
     recente por registrado_em
   - a sazonalidade é INVERTIDA: o pico é o mês ANTERIOR à data comemorativa
   - nunca use o schema bronze

   5 sample_questions e 5 pares pergunta -> SQL já validado, incluindo
   "Quem eu ligo essa semana?", "Quanto vale a fila desta semana?" e
   "Quantas ligações já foram registradas e quantas viraram pedido?".

   AS QUATRO REGRAS DA API QUE FAZEM O DEPLOY FALHAR:
   a) data_sources.tables ORDENADO por identifier
   b) column_configs de cada tabela ordenado por column_name
   c) todo id com 32 caracteres hexadecimais minúsculos, sem hífen
   d) as listas de perguntas e instruções também ordenadas por id

   Gere os ids com md5 do conteúdo — determinístico. Um redeploy não pode
   recriar as perguntas nem sujar o diff do Git.

3. Rode, e me mostre o resultado:
   databricks bundle validate --target dev --profile projeto-dados-ia
   databricks bundle deploy   --target dev --profile projeto-dados-ia
   bash scripts/rodar-tarefa.sh projeto-dados-ia gold_retorno_ligacao

   NÃO use --auto-approve. Se o deploy pedir para apagar o dashboard ou o
   genie_comercial, pare e me avise.
```

### Prompt 11 · O app

*a fila dos 200 na tela* · noite 4 · deploy nº 11 · [texto completo, com o que falar e as armadilhas](aulas/aula-04-app-e-genie/prd/prompt-02-app.md)

```
Crie um Databricks App para a direção comercial da Rota do Perfume, em
aulas/aula-04-app-e-genie/. Ele lê o que a noite 3 produziu — nenhuma tabela
nova.

1. O SCAFFOLD

   databricks apps init --name rotaperfume-direcao \
     --features analytics,genie \
     --set analytics.sql-warehouse.id=666be37e3fededf2 \
     --set genie.genie-space.id=<o id do space "Rota do Perfume · Direção"> \
     --set genie.genie-space.name="Rota do Perfume · Direção" \
     --description "A fila dos 200 na tela do diretor" \
     --run none --profile projeto-dados-ia

   Pegue o id do space com `databricks bundle summary --target dev` no bundle
   da noite 2, ou com `databricks genie list-spaces`. NÃO invente o id.

2. AS QUERIES, uma por arquivo em config/queries/ — nunca SQL dentro do React

   kpis_semana.sql   contatos, vendedores, receita esperada
                     (SUM(score*ticket_medio)), a referência da fila, mais
                     acertos_top200/lift_top200/taxa_base da ÚLTIMA versão de
                     gold.modelo_metricas (QUALIFY ROW_NUMBER() OVER
                     (ORDER BY versao DESC) = 1) e a contagem de
                     gold.retorno_ligacao
   vendedores.sql    vendedor -> contatos, para alimentar o filtro
   fila.sql          os 200 com todas as colunas de leitura humana (motivo,
                     sugestao), LEFT JOIN com o retorno mais recente de cada
                     cliente. Parâmetro `vendedor`, onde 'Todos' não filtra
   acompanhamento.sql  por vendedor: na_fila, trabalhados e a contagem de
                     cada status

   Anote os parâmetros com -- @param e dê valor de exemplo (= Todos), senão o
   typegen não consegue descrever a query.

   Rode `npm run typegen` com o WAREHOUSE LIGADO e me mostre a saída. Se
   aparecer OFFLINE ou "degraded", pare: os tipos saem como {} e o tsc quebra
   longe da causa real.

3. AS TELAS — três, no menu do topo, em português

   "A semana" (rota /):
     - quatro cartões no topo: contatos da semana (com o número de
       vendedores), receita esperada em reais, conversão prevista
       (acertos_top200/contatos em %) com a taxa base ao lado como
       comparação, e já trabalhados (com quantos viraram pedido)
     - um Select com os vendedores, mais a opção "Todos os vendedores"
     - a tabela da fila: ordem, cliente (razão social + cidade/UF + ticket),
       vendedor, chance em %, motivo e sugestão

   "Perguntar" (rota /perguntar):
     - o GenieChat do space do prompt 1
     - o e-mail de quem está logado, lido de uma rota /api/quem-sou que
       devolve o header x-forwarded-email
     - um aviso permanente de que a resposta é gerada por IA e traz o SQL que
       a produziu

   Toda tela precisa tratar os quatro estados: carregando (Skeleton), vazio
   (Empty, com uma frase útil — para um vendedor sem contatos, explique que a
   fila é global), erro (Alert, nunca painel em branco) e o dado.

   Formate em português: R$ com toLocaleString('pt-BR'), score como
   porcentagem inteira. Ninguém decide ligação lendo 0.9740085224443632.

   ATENÇÃO, e isto vale para TODA a tela: o warehouse devolve número como
   STRING no JSON, mesmo que o tipo gerado diga `number`. Passe por Number()
   antes de formatar ou somar — senão toLocaleString devolve a string intacta
   (R$ some e aparece 582799.4988012867) e "7" + "12" vira "712".

4. AS PERMISSÕES — sem isso o app sobe e mostra tela vazia

   Depois do primeiro deploy, leia o service principal do app com
   `databricks apps get rotaperfume-direcao -o json` (campo
   service_principal_client_id) e conceda:

     GRANT USE CATALOG ON CATALOG lakehouse_rotaperfume TO `<sp>`
     GRANT USE SCHEMA  ON SCHEMA  lakehouse_rotaperfume.gold TO `<sp>`
     GRANT SELECT      ON SCHEMA  lakehouse_rotaperfume.gold TO `<sp>`

   Leia o id do workspace, não copie de lugar nenhum: ele muda a cada app.

5. SUBA E ME MOSTRE A URL

   databricks apps validate --profile projeto-dados-ia
   databricks apps deploy -t default --profile projeto-dados-ia

   O target chama `default`, não `dev`. E é `apps deploy`, não
   `bundle deploy`: um bundle deploy cria o app parado, sem URL.
```

### Prompt 12 · O retorno

*o ciclo se fecha* · noite 4 · deploy nº 12 · [texto completo, com o que falar e as armadilhas](aulas/aula-04-app-e-genie/prd/prompt-03-retorno.md)

```
Continue o app rotaperfume-direcao. Ele lê a fila; agora ele precisa registrar
o que aconteceu na ligação.

1. A ROTA QUE ESCREVE — uma só, em server/server.ts, dentro de onPluginsReady

   POST /api/retorno, com o corpo validado por Zod ANTES de tocar no banco:
     cliente_id  int (use z.coerce.number(): a tela manda o id que veio do
                 warehouse, e ele chega como STRING mesmo tipado como number)
     vendedor    string não vazia
     status      enum: vendeu | vai_pensar | sem_interesse | nao_atendeu
     comentario  string, no máximo 500 caracteres, opcional
     referencia  string no formato aaaa-mm-dd

   Corpo inválido devolve 400 sem consultar o warehouse. O enum é o contrato:
   é ele que impede a tabela de ter "vendeu", "Vendeu" e "vendido".

   O INSERT vai por
   getExecutionContext().client.statementExecution.executeStatement, com
   warehouse_id vindo do próprio contexto, e TODO valor passado como
   parameters — nunca concatenado na string do SQL.

   registrado_por sai do header x-forwarded-email (com um valor local de
   desenvolvimento como reserva), registrado_em de current_timestamp().

   Mantenha também GET /api/quem-sou, que a aba Perguntar já usa.

   NÃO crie endpoint para ler nada: leitura continua sendo arquivo .sql.

2. OS BOTÕES, na tabela da aba "A semana"

   Uma coluna "Como foi a ligação". Para o cliente sem retorno: um campo de
   texto curto para o comentário e quatro botões — Vendeu, Vai pensar, Sem
   interesse, Não atendeu. O clique grava e desabilita enquanto grava.
   Para quem já tem retorno: mostre o status como Badge e o comentário
   embaixo, sem os botões.

   Se a gravação falhar, mostre um Alert com uma frase em português. Nunca
   engula o erro.

3. A RECARGA — sem isso a tela mente

   useAnalyticsQuery não tem refetch. Acrescente às queries fila.sql e
   kpis_semana.sql um parâmetro `recarga` que NÃO FILTRA NADA (algo como
   :recarga >= 0), e um contador na tela que sobe a cada gravação. Mudando o
   parâmetro, muda a chave do cache, e o dado é pedido de novo.

   Comente no .sql por que esse parâmetro existe — daqui a um mês ninguém
   lembra.

4. A ABA "Acompanhamento" (rota /acompanhamento)

   Lê acompanhamento.sql:
   - no topo, uma frase: quantos dos 200 foram trabalhados e quantos viraram
     pedido
   - um gráfico de barras por vendedor: trabalhados e vendeu
   - a tabela com o desfecho por vendedor

   Enquanto ninguém registrou nada, mostre um Empty dizendo que o número
   aparece assim que o time marcar o retorno — e que isso vira dado de treino
   da semana que vem. Zero não é erro.

5. A PERMISSÃO DE ESCRITA — escopada em uma tabela só

   GRANT MODIFY ON TABLE lakehouse_rotaperfume.gold.retorno_ligacao TO `<sp>`

   Em TABLE, não em SCHEMA. O app não pode alterar mais nada da gold.

6. Suba:
   databricks apps validate --profile projeto-dados-ia
   databricks apps deploy -t default --profile projeto-dados-ia
```
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
