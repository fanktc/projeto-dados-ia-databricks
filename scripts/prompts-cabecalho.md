# 🧾 Os 12 prompts, na ordem

Todo o projeto da Rota do Perfume — do CSV cru ao app com o retorno da ligação
— sai de **doze prompts colados em sequência no Claude Code**. Este arquivo é
a sequência inteira, na ordem, para quem quer refazer sozinho.

> **Cada prompt termina com um deploy.** Não junte dois: o valor do formato
> está em ver a coisa subir doze vezes, e em quebrar cedo quando quebra.

| Noite | Prompts | O que existe no fim |
|---|---|---|
| [**2** · engenharia](aulas/aula-02-engenharia-de-dados) | 1 a 6 | catálogo, pipeline de 12 tarefas, dashboard e Genie |
| [**3** · ciência de dados](aulas/aula-03-ciencia-de-dados) | 7 a 9 | modelo no Unity Catalog e a fila dos 200 · 15 tarefas |
| [**4** · apps e agentes](aulas/aula-04-app-e-genie) | 10 a 12 | Genie da direção, o app e o retorno da ligação · 16 tarefas |

---

## Antes do primeiro prompt

```bash
# 1 · o dataset (seed fixa: todo mundo gera exatamente o mesmo dado)
python3 material/gerar_dataset.py --saida ./dados --seed 42

# 2 · autenticar, e ESCOLHER um profile para usar a sequência inteira
databricks auth login
databricks auth profiles

# 3 · o catálogo, que a API do Unity Catalog não cria no Free Edition
cd aulas/aula-02-engenharia-de-dados/rotaperfume
bash scripts/criar-catalogo.sh <perfil>
```

**A pasta `rotaperfume/` do bundle nasce vazia** — é o prompt 1 que a preenche.
Se você já rodou antes, zere com
`bash aulas/aula-02-engenharia-de-dados/prd/00-reset.sh <perfil> --apagar`.

Nos prompts abaixo, **troque `projeto-dados-ia` pelo seu profile**.

---

## Como usar esta página

1. Copie o bloco do prompt (só o que está dentro do ```)
2. Cole no Claude Code, na raiz do repositório
3. Espere o deploy terminar e **confira o número** antes de ir para o próximo
4. O que conferir em cada um está no arquivo linkado no título

Os arquivos linkados têm o que esta página não tem: o que mostrar antes de
colar, o que falar enquanto o Claude Code trabalha, e a tabela **"se der
errado"**. Se for a primeira vez, siga por eles.

---

