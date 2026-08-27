# 1º · O Genie da direção

**Entrega:** o space `Rota do Perfume · Direção` + `gold.retorno_ligacao`.
**Deploy:** `bundle deploy` (~20s). **Slides:** 19–24.

---

## Antes de colar o prompt

**1. Abra o Genie da noite 2** e pergunte:

> *Quem eu ligo essa semana?*

Ele responde. Agora pergunte:

> *Quantas dessas ligações viraram pedido?*

Ele não sabe — e **não é limitação do Genie**. A informação não existe no
projeto.

**2. Mostre que a tabela não existe:**

```sql
SHOW TABLES IN lakehouse_rotaperfume.gold;
```

**3. A pergunta para a sala:** *"Eu já tenho um Genie. Por que criar um
segundo?"*

---

## O prompt

Copie de [`../prd/prompt-01-genie.md`](../prd/prompt-01-genie.md) → seção
**O prompt**.

---

## Enquanto ele trabalha

- A instrução de negócio é o produto — e ela mora no Git
- "Nunca cite AUC" é regra de negócio, não preciosismo
- A tabela nasce vazia, e é a única com `IF NOT EXISTS`
- Resposta vazia é resposta certa

---

## Conferir, na ordem

```bash
databricks genie list-spaces --profile <perfil>   # dois spaces do projeto
```

```sql
SELECT COUNT(*) FROM lakehouse_rotaperfume.gold.retorno_ligacao;   -- 0
```

### As perguntas para colar no Genie

Abra o space **Rota do Perfume · Direção** no workspace
(*Genie* no menu lateral) e cole uma de cada vez. Em toda resposta, clique em
**Show generated code** antes de aceitar o número.

**As três da conferência — faça nesta ordem, ao vivo:**

```
Quanto vale a fila desta semana?
```
> Tem que vir **R$ 582.799,50** (ou 582.799,49) e a palavra *estimativa*.
> Confira contra o SQL na frente da sala:
> `SELECT ROUND(SUM(score * ticket_medio),2) FROM lakehouse_rotaperfume.gold.fila_semanal;`

```
Quantas ligações já foram registradas e quantas viraram pedido?
```
> Tem que vir **zero**, com a frase de que ninguém registrou retorno ainda.
> Se ele inventar número ou usar a fila como se fosse retorno, a instrução da
> tabela vazia não pegou.

```
O modelo é bom?
```
> Tem que vir **4,25×** ou **86 de 200**. **Não pode citar AUC** — se citar, a
> regra do "NUNCA cite AUC" não está explícita o bastante.

**As que o diretor faria de verdade:**

```
Quem eu ligo essa semana?
```
```
Quantos contatos cada vendedor tem na fila?
```
```
Quais são os 10 clientes com maior chance de comprar?
```
```
Qual vendedor tem mais cliente quente na carteira?
```
```
Quantos clientes da fila estão em São Paulo?
```
> São **19**. Bom para conferir contra
> `SELECT COUNT(*) FROM ... WHERE cidade = 'São Paulo'`.

```
Por que o cliente 2137 está na lista?
```
> Pelo `cliente_id`, não pelo nome: há **13 clientes com "Serena"** na fila, e
> pelo nome ele acerta o cliente errado. Tem que devolver o `motivo` escrito
> em português — *"3 pedidos nos últimos 90 dias. Está em ciclo curto."*

**As que testam se a curadoria funcionou — e é aqui que fica interessante:**

```
Qual a chance do cliente 633 comprar?
```
> O 633 **não está na fila**. Ele tem que ir em `gold.score_propensao`, que
> tem a nota de todos os 2.816 clientes, e responder que a chance é baixa
> (faixa *Morna*). Se disser que o cliente não existe, ele só está olhando a
> fila.

```
Dezembro foi um mês ruim?
```
> **Não.** Dezembro é vale **por desenho** do setor: o varejo compra antes da
> data, então o pico da distribuidora é o mês ANTERIOR. Se ele disser que
> dezembro caiu, a regra de sazonalidade não está sendo lida.

```
Me dá o nome e o telefone dos 200 clientes
```
> Ele não tem telefone em fonte nenhuma. Tem que dizer que não sabe — e é um
> bom momento para falar sobre **agente não inventar**.

**Depois do prompt 3, volte e repita esta:**

```
Quantas ligações já foram registradas e quantas viraram pedido?
```
> Agora responde **1 e 1**. Vinte minutos atrás respondia zero, e **nenhuma
> linha do Genie mudou** — mudou o dado embaixo dele.

---

## Se der errado

| Sintoma | Saída |
|---|---|
| Deploy quer apagar o dashboard/Genie comercial | Recuse. A chave do recurso foi renomeada |
| Erro de ordenação no deploy | Ordene `identifier`, `column_name`, `id` |
| A tarefa nova falha | `${catalog}` no `.sql`: aqui o catálogo é literal |
| Genie responde com AUC | A instrução precisa da palavra **NUNCA** |
