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

No Genie novo, nesta ordem:

| Pergunta | Tem que responder |
|---|---|
| *Quanto vale a fila desta semana?* | **R$ 582.799,50** e a palavra *estimativa* |
| *Quantas ligações já foram registradas?* | **zero**, com a frase de que ninguém registrou |
| *O modelo é bom?* | **4,25×** ou *86 de 200*. **Nunca AUC** |

Confira o primeiro contra o SQL, na frente da sala. E use *Show generated code*
em toda resposta.

---

## Se der errado

| Sintoma | Saída |
|---|---|
| Deploy quer apagar o dashboard/Genie comercial | Recuse. A chave do recurso foi renomeada |
| Erro de ordenação no deploy | Ordene `identifier`, `column_name`, `id` |
| A tarefa nova falha | `${catalog}` no `.sql`: aqui o catálogo é literal |
| Genie responde com AUC | A instrução precisa da palavra **NUNCA** |
