/**
 * Utilidades compartilhadas pelas telas.
 *
 * O warehouse serializa TODO número como string no JSON, mesmo quando o tipo
 * gerado pelo typegen diz `number`. O compilador não reclama e o estrago
 * aparece na tela: `toLocaleString` devolve a string intacta e `+` concatena.
 * Por isso tudo aqui passa por Number() antes de qualquer conta ou formatação.
 */

export const num = (v: number | string | null | undefined) => Number(v ?? 0);

export const reais = (v: number | string) =>
  num(v).toLocaleString('pt-BR', {
    style: 'currency',
    currency: 'BRL',
    maximumFractionDigits: 0,
  });

export const pct = (v: number | string, casas = 0) =>
  `${(num(v) * 100).toFixed(casas)}%`;

/**
 * Semente de cache que muda a cada montagem da tela.
 *
 * `useAnalyticsQuery` guarda o resultado pela chave dos parâmetros e não expõe
 * `refetch`. Sem um valor que mude, quem grava um retorno e volta para a aba
 * continua vendo o número de antes. Em segundos para caber em INT.
 */
export const sementeDeCache = () => Math.floor(Date.now() / 1000);

/** Os quatro desfechos possíveis, na ordem em que o vendedor pensa neles. */
export const STATUS = [
  { valor: 'vendeu', rotulo: 'Vendeu', bom: true },
  { valor: 'vai_pensar', rotulo: 'Vai pensar', bom: false },
  { valor: 'sem_interesse', rotulo: 'Sem interesse', bom: false },
  { valor: 'nao_atendeu', rotulo: 'Não atendeu', bom: false },
] as const;

export const rotuloStatus = (valor: string) =>
  STATUS.find((s) => s.valor === valor)?.rotulo ?? valor;
