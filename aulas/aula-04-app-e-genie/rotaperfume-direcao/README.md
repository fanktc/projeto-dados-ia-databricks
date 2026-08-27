# Rota do Perfume · Direção

O app da noite 4 da Imersão Jornada de Dados. Três telas sobre a mesma tabela
que a noite 3 produziu — `lakehouse_rotaperfume.gold.fila_semanal`.

| Tela | O que faz |
|---|---|
| **A semana** | Os quatro números da semana e os 200 contatos, filtráveis por vendedor. Quatro botões por linha registram o resultado da ligação |
| **Acompanhamento** | O que a fila virou: trabalhados, vendas e desfecho por vendedor |
| **Perguntar** | O Genie `Rota do Perfume · Direção` embutido, com o SQL gerado à vista |

> **Este app lê muito e escreve pouco.** Toda leitura é um arquivo em
> `config/queries/`, tipado pelo Unity Catalog. A única escrita é
> `POST /api/retorno`, e ela grava uma linha em `gold.retorno_ligacao`.

---

## Como rodar

```bash
# desenvolvimento local (usa o profile do .env, warehouse remoto)
npm run dev

# validar antes de subir: lint, tipos, build e testes
databricks apps validate --profile <perfil>

# subir (o target chama `default`, não `dev`)
databricks apps deploy -t default --profile <perfil>
```

**Ligue o SQL warehouse antes do `npm run typegen`.** Com o warehouse parado, o
typegen degrada para `OFFLINE`, gera `{}` como tipo de resultado e o `tsc`
quebra com erros que não têm relação com o problema real.

---

## As permissões — o erro nº 1 de Databricks Apps

O app roda como um **service principal próprio**, criado junto com ele. Declarar
o warehouse com `permission: CAN_USE` no `databricks.yml` dá acesso ao
*compute*, **não ao dado**. Sem os `GRANT` abaixo, toda tela carrega vazia.

```bash
SP=$(databricks apps get rotaperfume-direcao --profile <perfil> -o json \
     | python3 -c "import json,sys; print(json.load(sys.stdin)['service_principal_client_id'])")

databricks experimental aitools tools query \
  "GRANT USE CATALOG ON CATALOG lakehouse_rotaperfume TO \`$SP\`" --profile <perfil>
databricks experimental aitools tools query \
  "GRANT USE SCHEMA ON SCHEMA lakehouse_rotaperfume.gold TO \`$SP\`" --profile <perfil>
databricks experimental aitools tools query \
  "GRANT SELECT ON SCHEMA lakehouse_rotaperfume.gold TO \`$SP\`" --profile <perfil>
databricks experimental aitools tools query \
  "GRANT MODIFY ON TABLE lakehouse_rotaperfume.gold.retorno_ligacao TO \`$SP\`" --profile <perfil>
```

O `MODIFY` é o único que dá escrita, e é escopado **em uma tabela só** — o app
não pode alterar mais nada da gold, nem apagar.

> O service principal **muda a cada app criado**. Leia sempre com
> `databricks apps get`; nunca copie o id de outro ambiente.

---

## Estrutura

```
config/queries/            as quatro leituras — o nome do arquivo é a queryKey
  kpis_semana.sql          contatos, receita esperada, conversão e retorno
  fila.sql                 os 200, com o último retorno de cada cliente
  vendedores.sql           quem tem cliente na fila (alimenta o filtro)
  acompanhamento.sql       o desfecho por vendedor
server/server.ts           /api/quem-sou e /api/retorno — a única escrita
client/src/pages/
  semana/                  A semana
  acompanhamento/          Acompanhamento
  genie/                   Perguntar
shared/appkit-types/       gerado por `npm run typegen` — não edite
```

### O parâmetro `recarga`

`useAnalyticsQuery` não expõe `refetch`. Depois de gravar um retorno, a tela
precisa perguntar de novo ao warehouse em vez de servir o cache — por isso
`fila.sql` e `kpis_semana.sql` têm um parâmetro `recarga` que não filtra nada:
quando ele muda, a chave do cache muda junto.

### Os tipos vêm do Unity Catalog

`npm run typegen` descreve cada query no warehouse e escreve
`shared/appkit-types/analytics.d.ts`. O `COMMENT` de cada coluna — exigido pela
auditoria de metadado da noite 2 — aparece como documentação no editor:

```ts
/** Probabilidade de o cliente fazer pedido nos próximos 7 dias, de 0 a 1. */
score: number;
```

**Metadado não é documentação para humano ler.** É o que o agente lê para
escolher a coluna, e o que o editor mostra para quem escreve a tela.
