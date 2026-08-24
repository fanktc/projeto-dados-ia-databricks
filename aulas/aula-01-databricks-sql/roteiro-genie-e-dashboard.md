# 🧞 Genie e 📊 Dashboard · o bloco sem código da noite 1

Dois ambientes onde ninguém escreve SQL — e os dois só funcionam porque o dado
está governado no Unity Catalog. É esse o argumento da noite.

---

## 🧞 Parte 1 · Genie

### O jeito mais rápido: `genie ask` na CLI

Não precisa criar nada. O Genie responde sobre o catálogo inteiro:

```bash
databricks genie ask "<pergunta>" --include-sql --profile SEU-PERFIL
```

O `--include-sql` é o que faz a demonstração valer: a turma vê o SQL que ele
escreveu, não só a resposta.

### Pergunta 1 — a pergunta da noite (funciona)

> Qual foi a receita total dos pedidos não cancelados na tabela
> rota_perfume.gold.fato_vendas?

Resposta obtida: **R$ 102.303.828,05** — o mesmo número do SQL escrito à mão e
do script Python local. Três ferramentas, um número.

Dois detalhes para apontar na tela:

1. Ele **rodou `SELECT DISTINCT status` antes** de filtrar, para descobrir quais
   status existem. Explorou o dado em vez de chutar.
2. O resultado bruto saiu como `1.0230382804999976E8` — ele usou
   `CAST(... AS DOUBLE)`. É o mesmo ruído de ponto flutuante que a gente evita
   com `DECIMAL(18,2)` no SQL da aula.

### Pergunta 2 — a que depende do dado limpo

> Quantos clientes únicos existem em rota_perfume.bronze.clientes considerando
> o CNPJ? Cuidado que o mesmo CNPJ pode estar escrito de formas diferentes.

Resposta obtida: **3.000 clientes** para 3.040 registros — e ele mostrou a
comparação: 3.024 CNPJs distintos sem normalizar contra 3.000 normalizando.

**Ele acertou.** Mas repare *por quê*: porque a pergunta já continha o aviso.
Faça a mesma pergunta sem a segunda frase e veja o que sai.

É o fecho da noite: o Genie foi o ambiente mais confortável dos três, e mesmo
assim só chegou no número certo porque quem perguntou sabia que o CNPJ vinha em
três formatos. Ele não descobre a sujeira — contorna, quando avisado.

> **Engenharia de dados não é o que a IA substitui. É o que faz a IA funcionar.**

### Comparação que fecha o argumento

Depois da noite 2, refaça a pergunta 2 sobre `rota_perfume.silver.clientes`.
Sem aviso nenhum, ele acerta — porque a dedup já aconteceu. É a prova de que a
camada silver não serve só ao analista: ela serve à IA também.

### Um Genie Space curado (opcional)

`genie ask` usa o Genie One, que enxerga o catálogo todo. Um **Genie Space**
é uma versão curada: você escolhe as tabelas, escreve instruções e dá exemplos
de query — e a taxa de acerto sobe muito.

Crie pela interface (a API exige um `serialized_space` que só se obtém
exportando um espaço existente):

1. Menu lateral → **Genie** → **New**
2. Tabelas: `rota_perfume.gold.fato_vendas`, `gold.dim_cliente`, `gold.dim_produto`
3. Warehouse: o Serverless Starter
4. Em **Instructions**, cole:

```
Você responde perguntas comerciais da Rota do Perfume, distribuidora B2B de
perfumaria árabe.

- Receita é SUM(receita) em gold.fato_vendas. Ela já exclui pedido cancelado.
- Devolução tem receita negativa e a flag `devolucao`. Para receita bruta,
  filtre NOT devolucao.
- Margem é SUM(margem) / SUM(receita).
- O pico de vendas é o mês ANTERIOR à data comemorativa: abril (Dia das Mães),
  junho (Namorados) e outubro (Black Friday). Dezembro e janeiro são vale.
- Nunca estime. Se o dado não responder, diga que não responde.
```

O item da sazonalidade é o mais valioso: sem ele, o Genie lê o gráfico ao
contrário, igual a um analista novo.

---

## 📊 Parte 2 · AI/BI Dashboard

O dashboard **já está criado e publicado** neste workspace, a partir de
`dashboard-receita.lvdash.json`.

### Como recriar do zero

```bash
databricks lakeview create \
  --display-name "Rota do Perfume · Noite 1" \
  --warehouse-id SEU-WAREHOUSE \
  --dataset-catalog rota_perfume \
  --dataset-schema gold \
  --serialized-dashboard "$(cat dashboard-receita.lvdash.json)" \
  --json '{"parent_path": "/Workspace/Users/SEU-EMAIL/dashboards"}' \
  --profile SEU-PERFIL

databricks lakeview publish DASHBOARD_ID --warehouse-id SEU-WAREHOUSE --profile SEU-PERFIL
```

### O que ele mostra

| Faixa | Widgets |
|---|---|
| Topo | Receita, pedidos, ticket médio e margem — cada um com sparkline |
| Meio | Receita por mês (a sazonalidade invertida) e receita por canal |
| Mix | Receita por marca e margem por categoria, lado a lado |
| Base | Top 15 clientes por receita |

### Três coisas para mostrar ao vivo

1. **O dashboard é um arquivo JSON versionado no Git.** Não é algo que alguém
   montou clicando e ninguém sabe reproduzir. Está em
   `dashboard-receita.lvdash.json`, ao lado do SQL da aula.

2. **Clique numa barra de marca.** Todos os widgets que usam o mesmo dataset
   filtram junto — é cross-filtering de graça, porque eles compartilham
   `ds_vendas`. Se cada widget tivesse seu próprio dataset, isso não
   aconteceria.

3. **O grão do dataset resolve o ticket médio.** `ds_pedidos` tem uma linha
   por pedido, então `AVG(valor)` já é o ticket médio correto — R$ 3.683,70 —
   sem precisar de razão de somas dentro do widget.

### ⚠️ A armadilha do `MEASURE()`

A primeira versão deste dashboard declarava as métricas em `dataset.columns` e
as chamava com `MEASURE()` nos KPIs. Parecia mais elegante: a conta escrita uma
vez só.

**Os quatro KPIs renderizaram "Unable to render visualization".** Os gráficos,
que usavam agregação inline, funcionaram normalmente.

A correção foi escolher o **grão do dataset** de forma que as agregações
permitidas já bastassem:

| KPI | Como resolve sem `MEASURE` |
|---|---|
| Receita | `SUM(valor)` sobre o dataset de pedidos |
| Pedidos | `COUNT(pedido_id)` |
| Ticket médio | `AVG(valor)` — correto porque cada linha é um pedido |
| Margem % | dataset próprio de **uma linha** com a razão já calculada em SQL |

A lição vale além do dashboard: **quando a ferramenta não deixa você calcular,
mude o grão do dado em vez de forçar a ferramenta.** Razão de somas
(`SUM(a)/SUM(b)`) não é expressão válida num widget — mas vira uma coluna
trivial no SQL do dataset.

### O gancho para a noite 2

Este dashboard lê da **gold**, que ainda não existia no começo da noite. Tente
apontá-lo para a bronze e ele quebra: `receita` lá é texto, e `data_pedido` tem
dois formatos.

O dashboard bonito depende da camada que a gente vai construir amanhã.
