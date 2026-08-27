import {
  useAnalyticsQuery,
  Alert,
  AlertDescription,
  BarChart,
  Card,
  CardContent,
  CardHeader,
  CardTitle,
  Empty,
  EmptyDescription,
  EmptyTitle,
  Skeleton,
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from '@databricks/appkit-ui/react';

export function AcompanhamentoPage() {
  const { data, loading, error } = useAnalyticsQuery('acompanhamento');

  const total = data?.reduce(
    (acc, l) => ({
      na_fila: acc.na_fila + l.na_fila,
      trabalhados: acc.trabalhados + l.trabalhados,
      vendeu: acc.vendeu + l.vendeu,
    }),
    { na_fila: 0, trabalhados: 0, vendeu: 0 },
  );

  return (
    <div className="space-y-6 w-full max-w-7xl mx-auto">
      <div>
        <h2 className="text-2xl font-bold text-foreground">Acompanhamento</h2>
        <p className="text-sm text-muted-foreground mt-1">
          {total
            ? `${total.trabalhados} de ${total.na_fila} contatos trabalhados · ${total.vendeu} viraram pedido`
            : 'O que a fila desta semana virou, vendedor por vendedor'}
        </p>
      </div>

      {error && (
        <Alert variant="destructive">
          <AlertDescription>Não consegui ler o acompanhamento: {error}</AlertDescription>
        </Alert>
      )}

      <Card>
        <CardHeader>
          <CardTitle>Contatos trabalhados por vendedor</CardTitle>
        </CardHeader>
        <CardContent>
          {loading && <Skeleton className="h-64 w-full" />}
          {!loading && !error && total?.trabalhados === 0 && (
            <Empty>
              <EmptyTitle>Nenhuma ligação registrada ainda</EmptyTitle>
              <EmptyDescription>
                Assim que o time marcar o retorno na aba “A semana”, o número aparece aqui — e vira
                dado de treino para a fila da semana que vem.
              </EmptyDescription>
            </Empty>
          )}
          {!loading && !error && (total?.trabalhados ?? 0) > 0 && (
            <BarChart queryKey="acompanhamento" xKey="vendedor" yKey={['trabalhados', 'vendeu']} />
          )}
        </CardContent>
      </Card>

      <Card>
        <CardHeader>
          <CardTitle>Desfecho, linha por linha</CardTitle>
        </CardHeader>
        <CardContent>
          {loading && <Skeleton className="h-40 w-full" />}
          {!loading && !error && (
            <div className="overflow-x-auto">
              <Table>
                <TableHeader>
                  <TableRow>
                    <TableHead>Vendedor</TableHead>
                    <TableHead className="text-right">Na fila</TableHead>
                    <TableHead className="text-right">Trabalhados</TableHead>
                    <TableHead className="text-right">Vendeu</TableHead>
                    <TableHead className="text-right">Vai pensar</TableHead>
                    <TableHead className="text-right">Sem interesse</TableHead>
                    <TableHead className="text-right">Não atendeu</TableHead>
                  </TableRow>
                </TableHeader>
                <TableBody>
                  {data?.map((l) => (
                    <TableRow key={l.vendedor}>
                      <TableCell className="font-medium">{l.vendedor}</TableCell>
                      <TableCell className="text-right">{l.na_fila}</TableCell>
                      <TableCell className="text-right">{l.trabalhados}</TableCell>
                      <TableCell className="text-right">{l.vendeu}</TableCell>
                      <TableCell className="text-right">{l.vai_pensar}</TableCell>
                      <TableCell className="text-right">{l.sem_interesse}</TableCell>
                      <TableCell className="text-right">{l.nao_atendeu}</TableCell>
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
