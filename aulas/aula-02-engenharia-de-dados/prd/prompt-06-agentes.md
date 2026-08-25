# Prompt 6 · Agentes de IA — o mesmo dado, outra porta

**Entrega:** views com nome de negócio, auditoria de metadado, o Genie space
configurado e as instruções do agente. **Deploy nº 6 — o último.**

> **O fechamento perfeito, porque fecha o arco da noite 1.** Ontem você plugou o
> Genie direto na bronze e avisou ao vivo: *"pode dar certo e pode dar errado,
> não fui eu que limpei esses dados"*. Hoje você mostra a diferença.

**Enquanto ele trabalha, você explica:**

- **O que faz o agente funcionar não é o modelo — é o dado.** O mesmo Genie, o
  mesmo LLM, a mesma pergunta. O que mudou nas duas horas foi tudo que está
  embaixo dele.
- **Metadado é interface.** `COMMENT` não é documentação para humano ler: é o
  que o agente lê para decidir qual coluna usar. Uma coluna chamada `vl_liq`
  sem comentário é uma coluna que o agente vai errar.
- **View com nome de negócio.** Ninguém da diretoria pergunta por
  `fato_vendas`. Perguntam por *ranking de marcas* e *clientes em risco*. A
  view existe para que o nome da pergunta e o nome da tabela sejam o mesmo.
- **Regra de negócio que o modelo não tem como adivinhar:** a sazonalidade
  invertida. Sem essa instrução, o agente lê o gráfico ao contrário e diz que
  dezembro foi ruim — quando dezembro é vale **por desenho** do setor.

---

## O prompt

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

## Validar ao vivo — o clímax da noite

Faça no Genie a **mesma pergunta de ontem**, agora sobre a gold:

> *"Quais marcas mais venderam nos últimos 6 meses?"*

E depois uma que **só funciona com dado limpo e documentado**:

> *"Quais clientes pararam de comprar, e quanta receita a gente perdeu com isso?"*

E a que prova que ele entendeu o negócio:

> *"Dezembro foi um mês ruim?"*
>
> A resposta certa é **não** — é vale de setor. Se ele responder que sim, a
> instrução de sazonalidade não entrou.
>
> **Resposta obtida no teste, palavra por palavra:** *"Dezembro é marcado como
> um mês de vale no setor, o que significa que é esperado ter menor receita,
> não sendo considerado um mês ruim. (…) Esse comportamento é normal, pois o
> varejo já está abastecido após os picos de vendas anteriores."*

---

## Fala de fechamento da noite

> *"Ontem eu pluguei o Genie direto na bronze e falei para vocês, com todas as
> letras: pode dar certo, pode dar errado, não fui eu que limpei esses dados.*
>
> *Hoje eu sei que está certo. E não é porque o modelo ficou mais inteligente
> de ontem para hoje — é o mesmo modelo. É porque eu construí o caminho inteiro
> e testei cada passo.*
>
> *Engenharia de dados não é o que a IA substitui. É o que faz a IA funcionar."*


---

## Se der errado ao vivo

| Sintoma | Causa | Correção em um prompt |
|---|---|---|
| `data_sources.tables must be sorted by identifier` | A lista está fora de ordem | Ordene por `identifier` |
| `sample_question.id must be provided` | Falta o id de 32 hex | Gere com md5 do conteúdo da pergunta |
| `example_question_sqls must be sorted by id` | As listas também são ordenadas | Ordene todas as listas por `id` |
| `multiple resources defined with the same key` | Dashboard e Genie usam a mesma chave | Renomeie uma das duas |
| O Genie responde que dezembro foi ruim | A instrução de sazonalidade não entrou | *"Reforce no texto que dezembro e janeiro são vale ESPERADO, e que ele nunca deve chamar isso de queda."* |
| Ele usa a bronze | As tabelas da bronze entraram como data_source | Só a gold entra. Escreva isso na instrução também |

**Tempo medido:** ~1min30 de deploy, ~4min30 do pipeline completo com 12 tarefas.

---

## O que fica de pé no fim da noite

| Camada | O quê |
|---|---|
| `bronze.raw` | Volume com os 10 CSVs, 14,7 MB |
| `bronze` | 10 tabelas Delta + a tabela de controle `_raw_arquivos` |
| `silver` | 10 tabelas limpas, com 5 constraints declaradas |
| `gold` | 4 dimensões, `fato_vendas` (191.080 linhas), 3 marts e 6 views de negócio |
| Job | `rotaperfume_pipeline`, 12 tarefas, agendado, com 11 testes que quebram |
| Dashboard | `Rota do Perfume · Comercial`, JSON versionado no bundle |
| Genie | `Rota do Perfume · Comercial`, instruções versionadas no bundle |

Tudo isso a partir de **seis prompts** e um catálogo vazio.
