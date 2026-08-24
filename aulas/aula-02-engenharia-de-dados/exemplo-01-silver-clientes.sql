-- ============================================
-- EXEMPLO 01: Silver de clientes — quatro sujeiras de uma vez
-- ============================================
-- Conceito: regexp_replace, lpad, initcap, ROW_NUMBER para deduplicar
-- Pergunta de negócio: quantos clientes a gente tem, de verdade?
-- Conexão com a aula 03: sem dedup aqui, o mesmo cliente vira dois no score
--
-- A bronze tem 3.040 linhas de cliente. Não são 3.040 clientes: 40 CNPJs
-- aparecem duas vezes, com id diferente e o número escrito de outro jeito.
--
-- Rode com:
--   python3 scripts/run_sql.py aulas/aula-02-engenharia-de-dados/exemplo-01-silver-clientes.sql

CREATE OR REPLACE TABLE rota_perfume.silver.clientes AS
WITH limpo AS (
    SELECT
        CAST(cliente_id AS INT)                                          AS cliente_id,

        -- Sujeira 1: CNPJ vem puro, pontuado ou com espaço em volta.
        -- trim tira o espaço, regexp tira pontuação, lpad devolve os zeros
        -- à esquerda. Nunca converta CNPJ para número: 309 começam com zero.
        lpad(regexp_replace(trim(cnpj), '[^0-9]', ''), 14, '0')          AS cnpj,

        -- Sujeira 2: razão social ora em CAIXA ALTA, ora sem acento.
        -- initcap padroniza a caixa. O acento não dá para recuperar —
        -- por isso o CNPJ é a chave, e não o nome.
        initcap(trim(regexp_replace(razao_social, '\\s+', ' ')))         AS razao_social,

        segmento, cidade, uf, bairro,

        -- Sujeira 3: data em ISO e em dd/MM/aaaa misturadas.
        -- try_to_date devolve NULL em vez de derrubar a query — com to_date
        -- puro, esta tabela não seria criada.
        coalesce(try_to_date(data_cadastro, 'yyyy-MM-dd'),
                 try_to_date(data_cadastro, 'dd/MM/yyyy'))               AS data_cadastro,

        ativo = 'S'                                                      AS ativo,
        _ingerido_em, _arquivo_origem
    FROM rota_perfume.bronze.clientes
),
numerado AS (
    SELECT
        *,
        -- Sujeira 4: o mesmo CNPJ cadastrado duas vezes. Ficamos com o
        -- cadastro mais antigo, que é o original — o segundo é o erro.
        ROW_NUMBER() OVER (PARTITION BY cnpj
                           ORDER BY data_cadastro ASC NULLS LAST, cliente_id) AS rn,
        COUNT(*)     OVER (PARTITION BY cnpj) > 1                        AS cnpj_duplicado
    FROM limpo
)
SELECT * EXCEPT (rn) FROM numerado WHERE rn = 1;


-- ----------------------------------------------------------------------------
-- O que mudou: 3.040 linhas viraram 3.000 clientes.
-- ----------------------------------------------------------------------------

SELECT
    (SELECT COUNT(*) FROM rota_perfume.bronze.clientes)                    AS bronze_linhas,
    (SELECT COUNT(*) FROM rota_perfume.silver.clientes)                    AS silver_clientes,
    (SELECT COUNT(*) FROM rota_perfume.silver.clientes WHERE cnpj_duplicado) AS eram_duplicados,
    (SELECT COUNT(DISTINCT cnpj) FROM rota_perfume.silver.clientes)        AS cnpj_unicos,
    (SELECT COUNT(*) FROM rota_perfume.silver.clientes WHERE data_cadastro IS NULL) AS datas_perdidas,
    (SELECT COUNT(*) FROM rota_perfume.silver.clientes WHERE length(cnpj) <> 14)    AS cnpj_mal_formado;
