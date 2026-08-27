"""Monta o PROMPTS.md a partir da seção "## O prompt" de cada arquivo de prd.

O texto NÃO é copiado à mão: é extraído dos arquivos originais, para o guia da
sequência e o material da noite nunca divergirem.
"""
import pathlib, re, sys

RAIZ = pathlib.Path(".")

PROMPTS = [
    # (noite, nº, título, subtítulo, caminho, deploy)
    (2, 1, "Raw", "os dez arquivos chegaram?",
     "aulas/aula-02-engenharia-de-dados/prd/prompt-01-raw.md",
     "bundle deploy + subir-raw.sh"),
    (2, 2, "Bronze", "CSV vira Delta, com a sujeira preservada",
     "aulas/aula-02-engenharia-de-dados/prd/prompt-02-bronze.md",
     "bundle deploy"),
    (2, 3, "Silver", "a limpeza, com CONSTRAINT declarada",
     "aulas/aula-02-engenharia-de-dados/prd/prompt-03-silver.md",
     "bundle deploy"),
    (2, 4, "Gold", "dimensões, fato, marts e os testes que quebram o job",
     "aulas/aula-02-engenharia-de-dados/prd/prompt-04-gold.md",
     "bundle deploy"),
    (2, 5, "Dashboard", "a gold vira tela",
     "aulas/aula-02-engenharia-de-dados/prd/prompt-05-dashboard.md",
     "bundle deploy"),
    (2, 6, "Genie comercial", "views com nome de negócio e metadado auditado",
     "aulas/aula-02-engenharia-de-dados/prd/prompt-06-agentes.md",
     "bundle deploy"),
    (3, 7, "Features", "o que descreve um cliente",
     "aulas/aula-03-ciencia-de-dados/prd/prompt-01-features.md",
     "bundle deploy"),
    (3, 8, "Modelo e MLflow", "o baseline que choca",
     "aulas/aula-03-ciencia-de-dados/prd/prompt-02-modelo.md",
     "bundle deploy"),
    (3, 9, "A fila e o agente", "os 200, com motivo",
     "aulas/aula-03-ciencia-de-dados/prd/prompt-03-fila-e-agente.md",
     "bundle deploy"),
    (4, 10, "Genie da direção", "o produto que se pergunta",
     "aulas/aula-04-app-e-genie/prd/prompt-01-genie.md",
     "bundle deploy"),
    (4, 11, "O app", "a fila dos 200 na tela",
     "aulas/aula-04-app-e-genie/prd/prompt-02-app.md",
     "apps deploy"),
    (4, 12, "O retorno", "o ciclo se fecha",
     "aulas/aula-04-app-e-genie/prd/prompt-03-retorno.md",
     "apps deploy"),
]

def extrair(caminho: str) -> str:
    """Devolve o conteúdo do primeiro bloco ``` depois de '## O prompt'."""
    txt = (RAIZ / caminho).read_text()
    depois = txt.split("## O prompt", 1)[1]
    m = re.search(r"```\n(.*?)\n```", depois, re.S)
    if not m:
        sys.exit(f"bloco não encontrado em {caminho}")
    return m.group(1).rstrip()

partes = []
for noite, n, titulo, sub, caminho, deploy in PROMPTS:
    corpo = extrair(caminho)
    partes.append(
        f"### Prompt {n} · {titulo}\n\n"
        f"*{sub}* · noite {noite} · deploy nº {n} · "
        f"[texto completo, com o que falar e as armadilhas]({caminho})\n\n"
        f"```\n{corpo}\n```\n"
    )

CABECALHO = pathlib.Path("scripts/prompts-cabecalho.md").read_text()
MEIO_2_3 = pathlib.Path("scripts/prompts-meio-23.md").read_text()
MEIO_3_4 = pathlib.Path("scripts/prompts-meio-34.md").read_text()
RODAPE = pathlib.Path("scripts/prompts-rodape.md").read_text()

texto = CABECALHO
texto += "## Noite 2 · o pipeline nasce\n\n" + "\n".join(partes[0:6]) + MEIO_2_3
texto += "## Noite 3 · o pipeline passa a decidir\n\n" + "\n".join(partes[6:9]) + MEIO_3_4
texto += "## Noite 4 · o projeto ganha uma URL\n\n" + "\n".join(partes[9:12]) + RODAPE

pathlib.Path("PROMPTS.md").write_text(texto)
print(f"{len(PROMPTS)} prompts → PROMPTS.md")
