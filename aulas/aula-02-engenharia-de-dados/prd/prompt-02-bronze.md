# Prompt 2 · Bronze — dez tabelas em um comando

**Entrega:** as 10 tabelas Delta da bronze, criadas por código, e a segunda
tarefa no job. **Deploy nº 2.**

> **A resposta direta à noite de ontem.** Eles subiram tabela por tabela na
> interface, uma de cada vez. Hoje é uma função e uma lista.

**Enquanto ele trabalha, você explica:**

- **Por que a bronze preserva a sujeira.** Se o Spark adivinhar o tipo, ele
  converte `15/10/2025` em nulo e apaga os zeros à esquerda de 309 CNPJs. A
  sujeira sumiria antes de vocês verem — e vocês nunca saberiam que ela existiu.
- **`inferColumnTypes => false` não é preguiça, é decisão.** Tudo entra como
  texto de propósito. Converter é trabalho da silver, feito sabendo o que se faz.
- **Metadado técnico.** `_ingerido_em` e `_arquivo_origem` respondem as duas
  primeiras perguntas de qualquer investigação: *quando isso entrou* e *de qual
  arquivo veio*.
- **Escreva a ingestão uma vez.** Dez tabelas, uma função, uma lista. Se amanhã
  o ERP mandar a décima primeira, é uma linha.

---

## O prompt

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

---

## Validar ao vivo

```sql
SELECT cliente_id, cnpj, razao_social, data_cadastro
FROM lakehouse_rotaperfume.bronze.clientes
WHERE cnpj LIKE '%.%' OR cnpj <> trim(cnpj)
LIMIT 10;
```

**Aponte na tela:** o CNPJ em três formatos e a razão social em CAIXA ALTA.
É a deixa literal para o prompt 3.

---

## Fala de aula

> *"Ontem isso levou vocês uns quinze minutos de clique. Agora foram noventa
> segundos — e olha o que eu ganhei junto: está no Git, roda de novo igual, e
> qualquer um da equipe consegue repetir sem me perguntar nada.*
>
> *Agora repara nessa coluna aqui. Três formatos de CNPJ na mesma tabela. Eu
> podia ter limpado na entrada, e ia parecer mais bonito. Mas aí, quando o
> número desse errado lá na frente, eu não teria como saber se o erro veio da
> origem ou da minha limpeza. A bronze é a prova. Ela nunca se edita."*


---

## Se der errado ao vivo

| Sintoma | Causa | Correção em um prompt |
|---|---|---|
| A contagem de `visitas` não bate | O número certo é **37.936**, não 38.112 | Confira contra `bronze._raw_arquivos`, não contra o PRD |
| Aparece uma coluna `_rescued_data` | O leitor de arquivo do Databricks cria essa coluna sozinho | *"Descarte com `SELECT * EXCEPT (_rescued_data)`."* Passar `rescuedDataColumn => ''` **não** desliga: cria uma coluna de nome vazio e o CREATE TABLE quebra |
| O CNPJ perdeu os zeros à esquerda | Alguém deixou o Spark inferir tipo | `inferSchema=False`. São 309 registros que somem calados |
| Data virou nulo na bronze | Mesma causa | A bronze não converte nada. Tudo é texto |

**Tempo medido:** ~50s de deploy, ~1min40 de execução das duas tarefas.
