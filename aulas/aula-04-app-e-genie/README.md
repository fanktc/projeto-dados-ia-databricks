# 🖥️ Dia 4: Apps e agentes | Imersão Jornada de Dados

Ontem o pipeline parou de dizer o que aconteceu e passou a dizer para quem
ligar. A fila dos 200 está na `gold.fila_semanal`, com nome, motivo e sugestão.

E aí veio a pergunta que ninguém tinha feito ainda — a pergunta que decide se
um projeto de dados vira produto ou vira pasta no Git:

> **"Tudo isso só abre no SQL Editor. E quem não escreve SQL?"**

> **Promessa da noite:** o projeto ganha uma URL.
> **Formato:** [3 prompts, 3 deploys](prd/3-prompts-noite-4.md). O bundle da
> terça ganha uma tabela e uma tarefa, e nasce um **Databricks App** ao lado.

---

## 🧠 A ideia da noite: acesso é entrega

Três noites de trabalho, e o resultado inteiro estava atrás de uma barreira que
o time de dados não enxerga porque já está do lado de dentro dela.

| Noite | O que ficou de pé | Quem consegue usar |
|---|---|---|
| 1 | O dado no catálogo | Quem escreve SQL |
| 2 | O pipeline, o dashboard e o Genie | + quem abre o dashboard |
| 3 | O modelo e a fila dos 200 | Quem escreve SQL |
| **4** | **O app e o Genie da direção** | **Quem não escreve nada** |

**Um dado que só o time de dados consegue abrir é um dado que não existe para a
empresa.** A noite 4 não cria nenhuma tabela de análise nova: ela pega o que já
está pronto e entrega uma URL — mais um caminho de volta, que é a parte que
quase todo projeto esquece.

---

## 📋 Os três prompts

| # | Entrega | Deploy | Arquivo |
|---|---|---|---|
| 1 | **O Genie da direção** — o produto que se pergunta | `bundle deploy` | [`prompt-01-genie.md`](prd/prompt-01-genie.md) |
| 2 | **O app** — a fila dos 200 na tela | `apps deploy` | [`prompt-02-app.md`](prd/prompt-02-app.md) |
| 3 | **O retorno** — o ciclo se fecha | `apps deploy` | [`prompt-03-retorno.md`](prd/prompt-03-retorno.md) |

### Prompt 1 · O Genie da direção — *o mesmo dado, outro recorte*

A noite 2 já criou um Genie: o **Comercial**, com doze fontes, que serve para
perguntar qualquer coisa sobre a operação. Hoje nasce o segundo — o da
**Direção** — com sete fontes, todas ligadas a uma decisão só.

> **Entrega:** o space `Rota do Perfume · Direção` como código no bundle, mais
> `gold.retorno_ligacao` — a tabela que vai receber a resposta do time, e que
> nasce **vazia**.
> **A ideia da vez:** Genie não é um por empresa. É **um por audiência** — o
> que muda entre eles não é o dado, é o recorte e a instrução.

### Prompt 2 · O app — *a fila dos 200 na tela*

`databricks apps init` monta um projeto React em ~60 segundos. As quatro
queries vêm de arquivos `.sql`, e o `COMMENT` que a noite 2 exigiu em toda
coluna vira **documentação dentro do editor** — o typegen lê o Unity Catalog e
escreve os tipos.

> **Entrega:** o app no ar, com a fila filtrável por vendedor e o Genie do
> prompt 1 embutido na aba *Perguntar*.
> **A armadilha da vez:** o app é **um usuário do Unity Catalog** e começa sem
> permissão nenhuma. Sem os três `GRANT` para o service principal, toda tela
> carrega vazia.

### Prompt 3 · O retorno — *o ciclo se fecha*

Quatro botões por linha: *Vendeu*, *Vai pensar*, *Sem interesse*, *Não
atendeu*. O clique grava em `gold.retorno_ligacao`, e a tela de acompanhamento
mostra a conversão real ao lado da prevista.

> **Entrega:** o endpoint que escreve, a aba *Acompanhamento* e a primeira
> linha de retorno gravada ao vivo.
> **O argumento da vez:** o que o vendedor responde hoje é **o rótulo de treino
> da semana que vem**. O dado que sai do pipeline volta para ele.

O roteiro da noite, com cronograma e as falas:
[`3-prompts-noite-4.md`](prd/3-prompts-noite-4.md).

---

## 🔢 Os números da noite

Medidos no workspace em 27/08, antes da aula:

| Onde | Número |
|---|---|
| Contatos na fila | **200**, distribuídos em **35** vendedores |
| Receita esperada | **R$ 582.799,50** — soma de `score × ticket_medio` |
| Conversão prevista | **43%** (86 dos 200) contra **10,1%** ligando às cegas |
| Ganho do modelo | **4,25×** — `lift_top200`, versão 3 |
| Maior score | **0,974** — Farmácia Serena, Goiânia |
| Retornos registrados | **0** no começo da noite, e é assim que tem que ser |

| Tempo medido | Quanto |
|---|---|
| `databricks apps init` | **~60s** |
| **Primeiro** `apps deploy` (cria o compute) | **3m44s** |
| Redeploy | **1m04s** |
| `bundle deploy` do Genie | **~20s** |

---

## 🚪 As três portas — e quando usar cada uma

No fim da noite 4 o mesmo `gold.fila_semanal` tem três consumidores. Não é
redundância: é audiência.

| Porta | Para quem | Ponto forte | Limite |
|---|---|---|---|
| **Dashboard** (noite 2) | Quem acompanha número recorrente | Zero código, agenda e alerta | Pergunta nova exige quem saiba editar |
| **Genie** (noites 2 e 4) | Quem tem pergunta que ninguém previu | Responde o que não estava na tela | Não escreve de volta, e às vezes erra |
| **App** (noite 4) | Quem trabalha a lista todo dia | Interação e **escrita de volta** | Alguém tem que manter o código |

> **Genie responde. App registra.** A diferença entre os dois não é a
> tecnologia — é a direção do dado.

---

## 🗂️ Onde o código mora

Dois artefatos, dois ciclos de deploy:

```
aulas/aula-02-engenharia-de-dados/rotaperfume/     o bundle das noites 2 e 3
└── resources/
    ├── direcao.geniespace.json        o Genie da direção, serializado
    └── genie-direcao.genie_space.yml  o recurso no bundle
└── src/gold/
    └── 11-retorno-ligacao.sql         a tabela que recebe a resposta do time

aulas/aula-04-app-e-genie/rotaperfume-direcao/     o app (bundle próprio)
├── app.yaml + databricks.yml          o app e os recursos que ele usa
├── config/queries/*.sql               as quatro leituras, tipadas
├── server/server.ts                   a única rota que ESCREVE
└── client/src/pages/                  A semana · Acompanhamento · Perguntar
```

### Como rodar

```bash
# 1 · o Genie (e a tabela de retorno) — no bundle da noite 2
cd aulas/aula-02-engenharia-de-dados/rotaperfume
databricks bundle deploy --target dev --profile <perfil>

# 2 · o app — bundle próprio, target `default`
cd ../../aula-04-app-e-genie/rotaperfume-direcao
databricks apps deploy -t default --profile <perfil>
```

> **`bundle deploy` não sobe app.** Ele cria o app parado, com `no_compute` e
> sem URL. Para app, o comando é `apps deploy`.

### Como voltar ao estado de início de aula

Depois de clicar nos botões durante um ensaio, a tabela de retorno fica suja —
e o momento do prompt 3 depende dela estar vazia (o Genie tem que responder
*"ninguém registrou ainda"*).

```bash
# zera só os retornos. A fila dos 200 e o modelo continuam intactos
bash prd/99-limpar-retornos.sh <perfil>            # simula
bash prd/99-limpar-retornos.sh <perfil> --apagar   # apaga

# apaga a noite 4 inteira: app, Genie da direção e a tabela
bash prd/99-limpar-aula-04.sh <perfil> --apagar
```

> **A fila não precisa ser recalculada.** Ela é determinística: `seed 42`,
> corte fixo, sem `current_date()`. Rodar `ml_fila` de novo devolve exatamente
> os mesmos 200 contatos — dá para conferir pelo `versao`, que sobe, com todo
> o resto igual.

No app, depois de limpar, clique em **Atualizar** na aba *Acompanhamento* ou
recarregue a página: a leitura é cacheada e a tela pode mostrar o número
antigo por alguns segundos.

### E o gabarito?

As noites 2 e 3 têm pasta `gabarito/` porque o código delas nasce vazio na
aula. Aqui não: **o app versionado neste repositório é o gabarito**. Se travar
ao vivo, abra `rotaperfume-direcao/config/queries/` e
`rotaperfume-direcao/server/server.ts` — é exatamente o que os prompts 2 e 3
produzem.

Para ensaiar do zero, rode o `99-limpar-aula-04.sh --apagar`: ele apaga o
projeto local junto com o app, e os prompts voltam a ter o que construir.

---

## ⚠️ Armadilhas medidas contra o workspace

1. **O app é um usuário do Unity Catalog.** `permission: CAN_USE` no warehouse
   **não** dá acesso aos dados. São necessários três `GRANT` para o service
   principal do app — e ele muda a cada app criado, então leia com
   `databricks apps get`, nunca copie de outro ambiente.

2. **O typegen precisa do warehouse ligado.** Parado, ele degrada para
   `OFFLINE`, gera `{}` como tipo, e o `tsc` quebra com erros que não têm nada
   a ver com o problema real.

3. **`useAnalyticsQuery` não tem `refetch`.** Depois de gravar, a tela não se
   atualiza sozinha. A saída é `cache: { enabled: false }` no `createApp` mais
   uma `key` que remonta o componente. **Não** use um parâmetro falso no SQL
   para furar o cache: quem estiver com o JS antigo aberto passa a mandar a
   consulta sem ele, e o warehouse recusa com `UNBOUND_SQL_PARAMETER`.

3b. **O tipo diz `number`, o runtime entrega `string`.** O warehouse serializa
   todo número como string no JSON, e o typegen não sabe disso. Sem `Number()`,
   `toLocaleString` devolve `582799.4988012867` cru, `"7" + "12"` vira `"712"`
   e um `z.number()` no servidor recusa o id que a própria tela mandou.

4. **`Unexpectedly failed to update app's compute size`.** Erro transitório do
   Free Edition ao trocar recursos do app. Rode o `apps deploy` de novo.

5. **O target do app é `default`, não `dev`.** O bundle do app é gerado pelo
   `apps init` e não herda os targets do bundle da noite 2.

6. **Não rode dois `apps deploy` ao mesmo tempo.** O segundo morre com
   `failed to acquire deployment lock`.

---

## 🎬 O fechamento

> *"Segunda a gente escreveu uma query que quebrou por causa de data em dois
> formatos. Terça aquilo virou pipeline. Quarta o pipeline passou a dizer para
> quem ligar.*
>
> *Hoje o vendedor clicou em 'Vendeu' — e esse clique virou uma linha na gold,
> que vai treinar o modelo da semana que vem.*
>
> *O dado saiu, deu a volta e voltou. Isso é um produto de dados.*
>
> *E vocês construíram junto. Não assistiram."*
