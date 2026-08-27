-- ============================================================================
-- A tabela que recebe a resposta do time.
--
-- Todas as outras tabelas da gold são ESCRITAS pelo pipeline e LIDAS por gente.
-- Esta é o contrário: nasce vazia, e quem escreve nela é o app da direção,
-- uma linha por ligação registrada.
--
-- É o caminho de volta. Sem ele, o projeto sabe a quem ligar e nunca fica
-- sabendo o que aconteceu depois — e o modelo da semana que vem treina com a
-- mesma informação da semana passada.
--
-- IF NOT EXISTS porque o job roda todo dia e o retorno do time não pode ser
-- apagado por um redeploy. Esta é a única tabela do projeto que o pipeline
-- cria mas não recria.
-- ============================================================================

CREATE TABLE IF NOT EXISTS lakehouse_rotaperfume.gold.retorno_ligacao (
  cliente_id     INT       COMMENT 'Cliente da fila que foi contatado. Junta com gold.fila_semanal e gold.dim_cliente.',
  vendedor       STRING    COMMENT 'Quem ligou, escrito igual a gold.fila_semanal.vendedor.',
  status         STRING    COMMENT 'Resultado da ligação: vendeu, vai_pensar, sem_interesse ou nao_atendeu.',
  comentario     STRING    COMMENT 'O que o cliente disse, em texto livre, escrito pelo vendedor.',
  registrado_em  TIMESTAMP COMMENT 'Quando o app gravou este retorno. Para o estado atual de um cliente, use o mais recente.',
  registrado_por STRING    COMMENT 'E-mail de quem estava logado no app quando registrou.',
  _referencia    DATE      COMMENT 'Semana da fila a que este retorno pertence, igual a gold.fila_semanal._referencia.'
)
COMMENT 'O que aconteceu depois da ligação. Escrita pelo app da direção, uma linha por contato registrado; é o rótulo real da semana seguinte.';
