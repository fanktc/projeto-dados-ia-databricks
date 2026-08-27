import { useMemo, useState } from 'react';
import {
  useAnalyticsQuery,
  Alert,
  AlertDescription,
  Badge,
  Button,
  Card,
  CardContent,
  CardHeader,
  CardTitle,
  Empty,
  EmptyDescription,
  EmptyTitle,
  Input,
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
  Skeleton,
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from '@databricks/appkit-ui/react';
import { sql } from '@databricks/appkit-ui/js';

const TODOS = 'Todos';

const STATUS = [
  { valor: 'vendeu', rotulo: 'Vendeu' },
  { valor: 'vai_pensar', rotulo: 'Vai pensar' },
  { valor: 'sem_interesse', rotulo: 'Sem interesse' },
  { valor: 'nao_atendeu', rotulo: 'Não atendeu' },
];

const reais = (v: number) =>
  v.toLocaleString('pt-BR', { style: 'currency', currency: 'BRL', maximumFractionDigits: 0 });

function Kpi({
  titulo,
  valor,
  apoio,
  carregando,
}: {
  titulo: string;
  valor: string;
  apoio: string;
  carregando: boolean;
}) {
  return (
    <Card>
      <CardHeader className="pb-2">
        <CardTitle className="text-sm font-medium text-muted-foreground">{titulo}</CardTitle>
      </CardHeader>
      <CardContent>
        {carregando ? (
          <Skeleton className="h-8 w-24" />
        ) : (
          <div className="text-3xl font-bold text-foreground">{valor}</div>
        )}
        <p className="text-xs text-muted-foreground mt-1">{apoio}</p>
      </CardContent>
    </Card>
  );
}

export function SemanaPage() {
  const [vendedor, setVendedor] = useState<string>(TODOS);
  const [comentarios, setComentarios] = useState<Record<number, string>>({});
  const [gravando, setGravando] = useState<number | null>(null);
  const [aviso, setAviso] = useState<string | null>(null);
  // Sobe a cada retorno gravado. Muda os parâmetros das queries, e é assim que a
  // tela volta a perguntar ao warehouse em vez de servir o cache.
  const [recarga, setRecarga] = useState(0);

  const parametrosKpis = useMemo(() => ({ recarga: sql.number(recarga) }), [recarga]);
  const kpis = useAnalyticsQuery('kpis_semana', parametrosKpis);
  const vendedores = useAnalyticsQuery('vendedores');
  const parametrosFila = useMemo(
    () => ({ vendedor: sql.string(vendedor), recarga: sql.number(recarga) }),
    [vendedor, recarga],
  );
  const fila = useAnalyticsQuery('fila', parametrosFila);

  const k = kpis.data?.[0];
  const conversaoPrevista = k ? (k.acertos_top200 / k.contatos) * 100 : 0;

  async function registrar(clienteId: number, nomeVendedor: string, status: string) {
    setGravando(clienteId);
    setAviso(null);
    try {
      const resposta = await fetch('/api/retorno', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          cliente_id: clienteId,
          vendedor: nomeVendedor,
          status,
          comentario: comentarios[clienteId] ?? '',
          referencia: k?.referencia ?? '2026-08-31',
        }),
      });
      if (!resposta.ok) throw new Error(await resposta.text());
      setRecarga((n) => n + 1);
    } catch {
      setAviso('Não consegui gravar esse retorno. Tente de novo.');
    } finally {
      setGravando(null);
    }
  }

  return (
    <div className="space-y-6 w-full max-w-7xl mx-auto">
      <div>
        <h2 className="text-2xl font-bold text-foreground">A semana</h2>
        <p className="text-sm text-muted-foreground mt-1">
          Os 200 clientes com maior chance de comprar nos próximos 7 dias
          {k ? ` · fila de ${k.referencia} · modelo versão ${k.versao}` : ''}
        </p>
      </div>

      {kpis.error && (
        <Alert variant="destructive">
          <AlertDescription>Não consegui ler os números da semana: {kpis.error}</AlertDescription>
        </Alert>
      )}
      {aviso && (
        <Alert variant="destructive">
          <AlertDescription>{aviso}</AlertDescription>
        </Alert>
      )}

      <div className="grid grid-cols-1 md:grid-cols-4 gap-4">
        <Kpi
          titulo="Contatos da semana"
          valor={k ? String(k.contatos) : '—'}
          apoio={k ? `${k.vendedores} vendedores` : 'carregando'}
          carregando={kpis.loading}
        />
        <Kpi
          titulo="Receita esperada"
          valor={k ? reais(k.receita_esperada) : '—'}
          apoio="soma de score × ticket médio"
          carregando={kpis.loading}
        />
        <Kpi
          titulo="Conversão prevista"
          valor={k ? `${conversaoPrevista.toFixed(0)}%` : '—'}
          apoio={k ? `contra ${(k.taxa_base * 100).toFixed(1)}% ligando às cegas` : 'carregando'}
          carregando={kpis.loading}
        />
        <Kpi
          titulo="Já trabalhados"
          valor={k ? `${k.ligacoes_registradas}` : '—'}
          apoio={k ? `${k.vendas} viraram pedido` : 'carregando'}
          carregando={kpis.loading}
        />
      </div>

      <Card>
        <CardHeader className="flex flex-row items-center justify-between gap-4">
          <CardTitle>Quem ligar primeiro</CardTitle>
          <Select value={vendedor} onValueChange={setVendedor}>
            <SelectTrigger className="w-64">
              <SelectValue placeholder="Todos os vendedores" />
            </SelectTrigger>
            <SelectContent>
              <SelectItem value={TODOS}>Todos os vendedores</SelectItem>
              {vendedores.data?.map((v) => (
                <SelectItem key={v.vendedor} value={v.vendedor}>
                  {v.vendedor} ({v.contatos})
                </SelectItem>
              ))}
            </SelectContent>
          </Select>
        </CardHeader>
        <CardContent>
          {fila.loading && (
            <div className="space-y-2">
              <Skeleton className="h-10 w-full" />
              <Skeleton className="h-10 w-full" />
              <Skeleton className="h-10 w-full" />
            </div>
          )}
          {fila.error && (
            <Alert variant="destructive">
              <AlertDescription>Não consegui ler a fila: {fila.error}</AlertDescription>
            </Alert>
          )}
          {!fila.loading && !fila.error && fila.data?.length === 0 && (
            <Empty>
              <EmptyTitle>Nenhum cliente nesta carteira</EmptyTitle>
              <EmptyDescription>
                A fila é global: quem tem carteira mais fria recebe menos contatos nesta semana.
              </EmptyDescription>
            </Empty>
          )}
          {!fila.loading && !fila.error && (fila.data?.length ?? 0) > 0 && (
            <div className="overflow-x-auto">
              <Table>
                <TableHeader>
                  <TableRow>
                    <TableHead className="w-12">#</TableHead>
                    <TableHead>Cliente</TableHead>
                    <TableHead>Vendedor</TableHead>
                    <TableHead className="text-right">Chance</TableHead>
                    <TableHead>Por que ligar</TableHead>
                    <TableHead>O que oferecer</TableHead>
                    <TableHead className="w-[26rem]">Como foi a ligação</TableHead>
                  </TableRow>
                </TableHeader>
                <TableBody>
                  {fila.data?.map((linha) => (
                    <TableRow key={linha.cliente_id}>
                      <TableCell className="text-muted-foreground">{linha.ordem}</TableCell>
                      <TableCell>
                        <div className="font-medium">{linha.razao_social}</div>
                        <div className="text-xs text-muted-foreground">
                          {linha.cidade}/{linha.uf} · ticket {reais(linha.ticket_medio)}
                        </div>
                      </TableCell>
                      <TableCell className="text-sm">{linha.vendedor}</TableCell>
                      <TableCell className="text-right font-medium">
                        {(linha.score * 100).toFixed(0)}%
                      </TableCell>
                      <TableCell className="text-sm max-w-xs">{linha.motivo}</TableCell>
                      <TableCell className="text-sm max-w-xs">{linha.sugestao}</TableCell>
                      <TableCell>
                        {linha.retorno_status ? (
                          <div className="space-y-1">
                            <Badge variant={linha.retorno_status === 'vendeu' ? 'default' : 'secondary'}>
                              {STATUS.find((s) => s.valor === linha.retorno_status)?.rotulo ??
                                linha.retorno_status}
                            </Badge>
                            {linha.retorno_comentario && (
                              <p className="text-xs text-muted-foreground">{linha.retorno_comentario}</p>
                            )}
                          </div>
                        ) : (
                          <div className="space-y-2">
                            <Input
                              placeholder="o que o cliente disse"
                              value={comentarios[linha.cliente_id] ?? ''}
                              onChange={(e) =>
                                setComentarios((c) => ({ ...c, [linha.cliente_id]: e.target.value }))
                              }
                            />
                            <div className="flex flex-wrap gap-1">
                              {STATUS.map((s) => (
                                <Button
                                  key={s.valor}
                                  size="sm"
                                  variant={s.valor === 'vendeu' ? 'default' : 'outline'}
                                  disabled={gravando === linha.cliente_id}
                                  onClick={() => registrar(linha.cliente_id, linha.vendedor, s.valor)}
                                >
                                  {s.rotulo}
                                </Button>
                              ))}
                            </div>
                          </div>
                        )}
                      </TableCell>
                    </TableRow>
                  ))}
                </TableBody>
              </Table>
            </div>
          )}
        </CardContent>
      </Card>
    </div>
  );
}
