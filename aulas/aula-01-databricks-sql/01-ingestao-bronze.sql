-- Noite 1 · Ingestão bronze
--
-- A bronze preserva o dado como veio. Nada de limpeza aqui: se der problema
-- depois, a gente precisa poder voltar na origem e comparar.
--
-- Duas opções que valem explicar:
--   inferColumnTypes => false  ->  TUDO entra como texto. Se deixássemos o Spark
--                                  adivinhar o tipo, ele erraria as datas que vêm
--                                  em dois formatos e o CNPJ perderia os zeros à
--                                  esquerda. A sujeira sumiria antes de a gente ver.
--   EXCEPT (_rescued_data)     ->  descarta a coluna extra que o read_files cria
--                                  sozinho, para a bronze ter só o que veio do CSV.
--
-- As duas colunas técnicas no fim (_ingerido_em, _arquivo_origem) respondem
-- "quando isso entrou?" e "de qual arquivo veio?" — as primeiras perguntas de
-- qualquer investigação.
--
-- Rode com:
--   python3 scripts/run_sql.py sql/n1_01_bronze.sql

-- ---------- ERP: o que foi vendido ----------

CREATE OR REPLACE TABLE rota_perfume.bronze.produtos AS
SELECT * EXCEPT (_rescued_data), current_timestamp() AS _ingerido_em, _metadata.file_path AS _arquivo_origem
FROM read_files('/Volumes/rota_perfume/bronze/raw/erp/produtos.csv',
                format => 'csv', header => true,
                inferColumnTypes => false);

CREATE OR REPLACE TABLE rota_perfume.bronze.pedidos AS
SELECT * EXCEPT (_rescued_data), current_timestamp() AS _ingerido_em, _metadata.file_path AS _arquivo_origem
FROM read_files('/Volumes/rota_perfume/bronze/raw/erp/pedidos.csv',
                format => 'csv', header => true,
                inferColumnTypes => false);

CREATE OR REPLACE TABLE rota_perfume.bronze.itens_pedido AS
SELECT * EXCEPT (_rescued_data), current_timestamp() AS _ingerido_em, _metadata.file_path AS _arquivo_origem
FROM read_files('/Volumes/rota_perfume/bronze/raw/erp/itens_pedido.csv',
                format => 'csv', header => true,
                inferColumnTypes => false);

CREATE OR REPLACE TABLE rota_perfume.bronze.pagamentos AS
SELECT * EXCEPT (_rescued_data), current_timestamp() AS _ingerido_em, _metadata.file_path AS _arquivo_origem
FROM read_files('/Volumes/rota_perfume/bronze/raw/erp/pagamentos.csv',
                format => 'csv', header => true,
                inferColumnTypes => false);

CREATE OR REPLACE TABLE rota_perfume.bronze.estoque AS
SELECT * EXCEPT (_rescued_data), current_timestamp() AS _ingerido_em, _metadata.file_path AS _arquivo_origem
FROM read_files('/Volumes/rota_perfume/bronze/raw/erp/estoque.csv',
                format => 'csv', header => true,
                inferColumnTypes => false);

-- ---------- CRM: para quem vendemos ----------

CREATE OR REPLACE TABLE rota_perfume.bronze.clientes AS
SELECT * EXCEPT (_rescued_data), current_timestamp() AS _ingerido_em, _metadata.file_path AS _arquivo_origem
FROM read_files('/Volumes/rota_perfume/bronze/raw/crm/clientes.csv',
                format => 'csv', header => true,
                inferColumnTypes => false);

CREATE OR REPLACE TABLE rota_perfume.bronze.vendedores AS
SELECT * EXCEPT (_rescued_data), current_timestamp() AS _ingerido_em, _metadata.file_path AS _arquivo_origem
FROM read_files('/Volumes/rota_perfume/bronze/raw/crm/vendedores.csv',
                format => 'csv', header => true,
                inferColumnTypes => false);

CREATE OR REPLACE TABLE rota_perfume.bronze.carteira AS
SELECT * EXCEPT (_rescued_data), current_timestamp() AS _ingerido_em, _metadata.file_path AS _arquivo_origem
FROM read_files('/Volumes/rota_perfume/bronze/raw/crm/carteira.csv',
                format => 'csv', header => true,
                inferColumnTypes => false);

CREATE OR REPLACE TABLE rota_perfume.bronze.oportunidades AS
SELECT * EXCEPT (_rescued_data), current_timestamp() AS _ingerido_em, _metadata.file_path AS _arquivo_origem
FROM read_files('/Volumes/rota_perfume/bronze/raw/crm/oportunidades.csv',
                format => 'csv', header => true,
                inferColumnTypes => false);

CREATE OR REPLACE TABLE rota_perfume.bronze.visitas AS
SELECT * EXCEPT (_rescued_data), current_timestamp() AS _ingerido_em, _metadata.file_path AS _arquivo_origem
FROM read_files('/Volumes/rota_perfume/bronze/raw/crm/visitas.csv',
                format => 'csv', header => true,
                inferColumnTypes => false);
