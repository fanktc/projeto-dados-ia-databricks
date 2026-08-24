-- Noite 1 · Setup do ambiente
-- Cria a casa onde o dado vai morar: um catálogo, três schemas e um volume.
--
-- Rode com:
--   databricks experimental aitools tools query --profile projeto-dados-ia --file aulas/aula-01-databricks-sql/00-setup-catalogo.sql

-- O catálogo é o topo da hierarquia no Unity Catalog: catálogo > schema > tabela.
CREATE CATALOG IF NOT EXISTS lakehouse_rotaperfume
  COMMENT 'Imersão Jornada de Dados — distribuidora Rota do Perfume';

-- Os três schemas são as três camadas do medallion. Criamos os três agora,
-- mesmo que hoje só a bronze receba dado: o desenho vem antes do código.
CREATE SCHEMA IF NOT EXISTS lakehouse_rotaperfume.bronze
  COMMENT 'Ingestão crua. O dado como veio da origem, sujeira inclusa.';
CREATE SCHEMA IF NOT EXISTS lakehouse_rotaperfume.silver
  COMMENT 'Limpo, deduplicado e tipado. Preenchido na noite 2.';
CREATE SCHEMA IF NOT EXISTS lakehouse_rotaperfume.gold
  COMMENT 'Fatos e dimensões, modelado para consumo. Preenchido na noite 2.';

-- O volume guarda ARQUIVO, não tabela. É para onde os CSVs sobem antes de virar Delta.
CREATE VOLUME IF NOT EXISTS lakehouse_rotaperfume.bronze.raw
  COMMENT 'CSVs originais de ERP e CRM, exatamente como saíram do gerador.';
