#!/usr/bin/env python3
"""Slides da Noite 3 — ciência de dados: da gold para a decisão.

Slide também é código. Os tokens de design vêm do deck da Noite 1, e os
arquétipos são os mesmos de `aula-02/slides/gerar_slides.py`: os três decks
desenham a mesma coisa.

TODO NÚMERO AQUI FOI MEDIDO contra o workspace, rodando o pipeline de ponta a
ponta com seed 42. Nada é estimativa.

Uso:  python gerar_slides.py        (precisa de python-pptx)
"""
from pptx import Presentation
from pptx.dml.color import RGBColor
from pptx.enum.shapes import MSO_SHAPE
from pptx.enum.text import PP_ALIGN, MSO_ANCHOR
from pptx.util import Inches, Pt

# ── tokens do sistema de design da Noite 1 ────────────────────────────
FUNDO      = RGBColor(0x07, 0x0C, 0x16)
ACENTO     = RGBColor(0x3B, 0x9D, 0xF5)
ACENTO_CLR = RGBColor(0x7C, 0xC8, 0xFF)
BRANCO     = RGBColor(0xFF, 0xFF, 0xFF)
CINZA      = RGBColor(0x9B, 0xAA, 0xC0)
MARCA      = RGBColor(0x56, 0x6A, 0x85)
CARD       = RGBColor(0x0D, 0x15, 0x22)
CARD_BORDA = RGBColor(0x1F, 0x3A, 0x5A)
DESTAQUE   = RGBColor(0x14, 0x23, 0x37)
CODIGO     = RGBColor(0x7C, 0xC8, 0xFF)

LARGURA, ALTURA = Inches(40), Inches(22.5)

prs = Presentation()
prs.slide_width, prs.slide_height = LARGURA, ALTURA
BRANCA = prs.slide_layouts[6]


def nova():
    s = prs.slides.add_slide(BRANCA)
    f = s.background.fill
    f.solid()
    f.fore_color.rgb = FUNDO
    return s


def texto(s, txt, x, y, w, h, tam, cor, negrito=False, fonte="Arial",
          alinha=PP_ALIGN.LEFT, entrelinha=1.0):
    cx = s.shapes.add_textbox(Inches(x), Inches(y), Inches(w), Inches(h))
    tf = cx.text_frame
    tf.word_wrap = True
    tf.margin_left = tf.margin_right = tf.margin_top = tf.margin_bottom = 0
    tf.vertical_anchor = MSO_ANCHOR.TOP
    for i, linha in enumerate(txt.split("\n")):
        p = tf.paragraphs[0] if i == 0 else tf.add_paragraph()
        p.alignment = alinha
        p.line_spacing = entrelinha
        r = p.add_run()
        r.text = linha
        r.font.name = fonte
        r.font.size = Pt(tam)
        r.font.bold = negrito
        r.font.color.rgb = cor
    return cx


def caixa(s, x, y, w, h, destaque=False):
    sh = s.shapes.add_shape(MSO_SHAPE.ROUNDED_RECTANGLE, Inches(x), Inches(y), Inches(w), Inches(h))
    sh.adjustments[0] = 0.06
    sh.fill.solid()
    sh.fill.fore_color.rgb = DESTAQUE if destaque else CARD
    sh.line.color.rgb = ACENTO if destaque else CARD_BORDA
    sh.line.width = Pt(6.4 if destaque else 4.0)
    sh.shadow.inherit = False
    return sh


def assinatura(s):
    texto(s, "JORNADA DE DADOS", 1.8, 20.48, 12.0, 1.0, 32, MARCA, True)


# ── arquétipo 1: divisor ──────────────────────────────────────────────
def divisor(chapeu, titulo, linha):
    s = nova()
    barra = s.shapes.add_shape(MSO_SHAPE.RECTANGLE, Inches(0), Inches(0), Inches(0.7), ALTURA)
    barra.fill.solid()
    barra.fill.fore_color.rgb = ACENTO
    barra.line.fill.background()
    barra.shadow.inherit = False
    texto(s, chapeu, 2.8, 6.2, 30.0, 2.0, 52, ACENTO, True)
    texto(s, titulo, 2.8, 8.0, 34.4, 6.0, 168, BRANCO, True, entrelinha=0.95)
    texto(s, linha, 2.8, 15.6, 32.0, 2.4, 60, CINZA)
    return s


# ── arquétipo 2: linhas em card ───────────────────────────────────────
# itens: (rotulo, corpo) ou (rotulo, corpo, destaque). De 3 a 6 linhas.
MEDIDAS = {3: (3.02, 0.42, 62, 50), 4: (2.55, 0.34, 54, 44),
           5: (2.05, 0.30, 46, 38), 6: (1.66, 0.27, 40, 33)}


def linhas(chapeu, titulo, itens, rodape=None, mono=False):
    s = nova()
    texto(s, chapeu, 1.8, 1.8, 32.0, 1.12, 44, ACENTO, True)
    texto(s, titulo, 1.8, 3.5, 36.4, 4.4, 128, BRANCO, True, entrelinha=0.95)

    altura, folga, tam_rot, tam_corpo = MEDIDAS[len(itens)]
    topo = 8.17
    for i, item in enumerate(itens):
        rotulo, corpo = item[0], item[1]
        destaque = len(item) > 2 and item[2]
        y = topo + i * (altura + folga)
        caixa(s, 1.77, y, 36.46, altura, destaque)
        texto(s, rotulo, 3.0, y + altura * 0.20, 10.4, altura, tam_rot,
              ACENTO if destaque else BRANCO, True,
              fonte="Courier New" if mono else "Arial")
        texto(s, corpo, 13.8, y + altura * 0.20, 23.2, altura, tam_corpo,
              CINZA, entrelinha=1.05)
    if rodape:
        texto(s, rodape, 1.8, 19.35, 36.0, 1.4, 46, ACENTO_CLR)
    assinatura(s)
    return s


# ── arquétipo 3: quatro números ───────────────────────────────────────
def numeros(chapeu, titulo, tiles):
    s = nova()
    texto(s, chapeu, 1.8, 1.8, 32.0, 1.12, 44, ACENTO, True)
    texto(s, titulo, 1.8, 3.5, 36.4, 4.4, 128, BRANCO, True, entrelinha=0.95)
    for i, (simbolo, valor, desc) in enumerate(tiles[:4]):
        x = 1.77 + i * 9.28
        caixa(s, x, 9.57, 8.62, 7.66)
        texto(s, simbolo, x + 0.91, 10.32, 6.8, 1.2, 44, ACENTO, True)
        texto(s, valor, x + 0.91, 11.46, 6.8, 2.3, 58, BRANCO, True, entrelinha=0.95)
        texto(s, desc, x + 0.91, 14.0, 6.8, 2.9, 42, CINZA, entrelinha=1.05)
    assinatura(s)
    return s



# ── arquétipo 4: o fluxo (o que vamos construir) ──────────────────────
def fluxo(chapeu, titulo, subtitulo, etapas, faixa, paineis):
    """etapas: (camada, titulo, corpo). paineis: (nome, [linhas], nota)."""
    s = nova()
    texto(s, chapeu, 1.8, 1.4, 32.0, 1.0, 40, ACENTO, True)
    texto(s, titulo, 1.8, 2.6, 36.4, 3.0, 96, BRANCO, True, entrelinha=0.95)
    texto(s, subtitulo, 1.8, 5.5, 36.4, 1.2, 46, CINZA)

    # a esteira de camadas
    largura, folga, topo, altura = 5.6, 0.55, 7.3, 6.0
    for i, (camada, tit, corpo) in enumerate(etapas):
        x = 1.8 + i * (largura + folga)
        ultimo = i == len(etapas) - 1
        caixa(s, x, topo, largura, altura, destaque=ultimo)
        texto(s, camada, x + 0.45, topo + 0.45, largura - 0.9, 0.9, 30, ACENTO, True)
        texto(s, tit, x + 0.45, topo + 1.5, largura - 0.9, 1.6, 34, BRANCO, True, entrelinha=0.95)
        texto(s, corpo, x + 0.45, topo + 3.15, largura - 0.9, 2.6, 24, CINZA, entrelinha=1.15)
        if not ultimo:
            texto(s, "→", x + largura, topo + altura / 2 - 0.55, folga, 1.1, 44,
                  ACENTO, True, alinha=PP_ALIGN.CENTER)

    # a faixa que atravessa tudo
    faixa_sh = caixa(s, 1.8, 13.75, 36.4, 1.15)
    texto(s, faixa, 1.8, 14.05, 36.4, 0.8, 30, ACENTO_CLR, True, alinha=PP_ALIGN.CENTER)

    # os três painéis de baixo
    pw, pfolga, py, ph = 11.6, 0.8, 15.4, 4.1
    for i, (nome, itens, nota) in enumerate(paineis[:3]):
        x = 1.8 + i * (pw + pfolga)
        caixa(s, x, py, pw, ph)
        texto(s, nome, x + 0.6, py + 0.35, pw - 1.2, 0.8, 28, ACENTO, True)
        texto(s, "\n".join("· " + i2 for i2 in itens), x + 0.6, py + 1.3, pw - 1.2, 2.0,
              26, CINZA, entrelinha=1.25)
        texto(s, nota, x + 0.6, py + ph - 0.95, pw - 1.2, 0.8, 24, MARCA, True)
    assinatura(s)
    return s


# ── arquétipo 5: quatro colunas de dor ────────────────────────────────
def colunas(chapeu, titulo, subtitulo, cols, saida_nome, saida_itens, saida_nota):
    """cols: (etiqueta, manchete, corpo)."""
    s = nova()
    texto(s, chapeu, 1.8, 1.4, 32.0, 1.0, 40, ACENTO, True)
    texto(s, titulo, 1.8, 2.6, 36.4, 3.4, 104, BRANCO, True, entrelinha=0.95)
    texto(s, subtitulo, 1.8, 6.3, 36.4, 1.2, 48, CINZA)

    cw, cfolga, cy, ch = 8.5, 0.8, 8.6, 7.4
    for i, (etiqueta, manchete, corpo) in enumerate(cols[:4]):
        x = 1.8 + i * (cw + cfolga)
        caixa(s, x, cy, cw, ch)
        texto(s, etiqueta, x + 0.7, cy + 0.6, cw - 1.4, 0.8, 30, ACENTO, True)
        texto(s, manchete, x + 0.7, cy + 1.7, cw - 1.4, 2.4, 50, BRANCO, True, entrelinha=0.95)
        texto(s, corpo, x + 0.7, cy + 4.5, cw - 1.4, 2.6, 32, CINZA, entrelinha=1.15)

    caixa(s, 1.8, 16.6, 36.4, 3.0, destaque=True)
    texto(s, saida_nome, 2.6, 17.0, 9.0, 0.9, 34, ACENTO, True)
    texto(s, "   ·   ".join(saida_itens), 2.6, 18.05, 26.0, 1.0, 44, BRANCO, True)
    texto(s, saida_nota, 29.0, 18.15, 8.4, 1.0, 30, ACENTO_CLR, True, alinha=PP_ALIGN.RIGHT)
    assinatura(s)
    return s



# ══════════════════════════════════════════════════════════════════════
#  PARTE 0 · A PONTE — DO PIPELINE QUE CONTA PARA O QUE DECIDE
# ══════════════════════════════════════════════════════════════════════

divisor("NOITE 3 · QUARTA 26/08",
        "Do que aconteceu\npara o que fazer",
        "O pipeline para de contar o passado. Em seis prompts, ele passa a dizer para quem ligar amanhã.")

# ── a dor que justifica a noite ───────────────────────────────────────
colunas("A DOR DE HOJE",
        "A gold responde tudo\nsobre ontem",
        "E ninguém consegue responder a única pergunta que o vendedor faz de manhã.",
        [
          ("RETROVISOR", "Só olha\npara trás",
           "Receita por mês, margem por marca. Tudo já aconteceu."),
          ("PRIORIDADE", "3.000 clientes,\nnenhuma ordem",
           "Por onde começar? Hoje a resposta é ordem alfabética."),
          ("INTUIÇÃO", "Ninguém\nmediu",
           "'Ligue para quem parou de comprar' — será que funciona?"),
          ("AÇÃO", "Dashboard\nnão liga",
           "Ver o número não é decidir. Falta a lista de nomes."),
        ],
        "A SAÍDA",
        ["Features", "Modelo no UC", "Score em batch", "Carteira do dia"],
        "o dado vira decisão")

# ── onde a gente vai chegar ───────────────────────────────────────────
fluxo("QUEM SABE FAZ AO VIVO",
      "O que vamos construir hoje",
      "Seis tarefas novas no MESMO pipeline da terça. ML é camada, não projeto à parte.",
      [
        ("FEATURES", "Uma linha por cliente", "22 features · uma função\ncom a data por parâmetro\nsem vazamento, por desenho"),
        ("TREINO", "MLflow + Unity Catalog", "baseline medido antes\nmodelo vira objeto\nde catálogo, com linhagem"),
        ("PROMOÇÃO", "Challenger vs prod", "o treino não promove\nquem decide é uma regra\ne ela deixa registro"),
        ("SCORE", "Delta na gold", "@prod → predict_proba\n2.816 clientes\ncom faixa e versão"),
        ("TESTES", "8 que quebram o job", "ganha do baseline?\nbom demais é bug\ncobertura e distribuição"),
        ("DECISÃO", "A carteira do dia", "1.290 contatos\nem ordem, com o motivo\nescrito em português"),
      ],
      "UM JOB · 18 TAREFAS · 19 TESTES QUE QUEBRAM O PIPELINE · UM ÚNICO bundle run",
      [
        ("O MESMO BUNDLE",
         ["nada de repositório novo", "mesma auditoria de metadado", "mesmos testes que interrompem"],
         "ML é camada, não projeto"),
        ("MEDIDO, NÃO DITO",
         ["baseline antes do modelo", "importância por permutação", "calibragem no holdout"],
         "toda afirmação tem query"),
        ("SEED 42",
         ["mesmo número para todo mundo", "corte fixo em 2026-08-01", "nada de current_date()"],
         "dá para conferir na tela"),
      ])

linhas("RECAP DAS DUAS NOITES", "O que já está\nde pé", [
    ("Noite 1 · SQL", "A query quebrou por causa de data em dois formatos. Consertamos no braço."),
    ("Noite 2 · Engenharia", "Aquilo virou camada: escrito uma vez, testado, agendado. 12 tarefas."),
    ("A gold", "191.080 linhas no fato · R$ 102.303.828,05 · 11 testes que quebram o job."),
    ("O que falta", "Tudo isso responde no passado. Hoje o pipeline aprende a responder no futuro.", True),
], rodape="O bundle não muda de nome nem de lugar. Ele só ganha mais seis tarefas.")

# ══════════════════════════════════════════════════════════════════════
#  PARTE 1 · O MOMENTO DA NOITE — O BASELINE
# ══════════════════════════════════════════════════════════════════════

divisor("A PERGUNTA DA NOITE",
        "Para quem o vendedor\ndeve ligar amanhã?",
        "Antes de qualquer código: responda. Daqui a vinte minutos a gente mede a sua resposta.")

numeros("MEDIMOS AS RESPOSTAS DA SALA", "A intuição comercial,\nna régua do AUC", [
    ("0,4329", "recência", "'ligue para quem comprou recentemente'"),
    ("0,5000", "moeda", "jogar cara ou coroa"),
    ("0,6432", "frequência", "'ligue para quem compra mais'"),
    ("0,8667", "o modelo", "as mesmas colunas, ordenadas por um modelo"),
])

linhas("POR QUE 0,43 E NÃO 0,60", "A intuição não está\nimprecisa. Está\ninvertida.", [
    ("O ciclo de reposição", "O varejista acabou de receber a mercadoria. Ele não compra de novo agora."),
    ("Quem comprou ontem", "É justamente quem NÃO está pronto para o próximo pedido."),
    ("Ordenar por recência", "Coloca no topo da lista exatamente quem menos vai comprar.", True),
    ("E ninguém tinha medido", "Não é que o gerente seja ruim. É que a régua nunca foi colocada."),
], rodape="AUC abaixo de 0,5 significa que seguir o contrário da regra seria melhor.")

# ══════════════════════════════════════════════════════════════════════
#  PARTE 2 · AS QUATRO IDEIAS QUE A NOITE DEFENDE
# ══════════════════════════════════════════════════════════════════════

linhas("IDEIA 1 · FEATURE", "A coluna que vale\ndinheiro não vem\nde biblioteca", [
    ("recencia_dias", "Está em todo tutorial. Sozinha, tem AUC de 0,43 nesta operação."),
    ("intervalo_medio_dias", "De quanto em quanto tempo ESTE cliente costuma voltar."),
    ("atraso_relativo", "A divisão das duas. Sumiu há 20 dias: é rotina ou é o dobro do normal dele?", True),
    ("A prova", "Importância por permutação: é a feature nº 1 do modelo. Medida, não afirmada."),
], rodape="Isso não é ciência de dados. É conhecimento de negócio, escrito como divisão.")

linhas("IDEIA 2 · VAZAMENTO", "Vazamento não parece\nerro. Parece\nsucesso.", [
    ("O sintoma", "AUC de 1,0000. Acerto perfeito nos 704 clientes. Print no grupo."),
    ("A causa", "Uma feature enxergou o que aconteceu DEPOIS do rótulo. Um filtro a menos."),
    ("A consequência", "Em produção despenca — e ninguém entende, porque na validação estava lindo."),
    ("A defesa", "Uma função com a data por parâmetro. E um teste que QUEBRA o job se o AUC ≥ 0,99.", True),
], rodape="Quebrar o pipeline porque o resultado ficou bom demais. É por isso que funciona.")

linhas("IDEIA 3 · TESTE DE MODELO", "Um dado errado quebra.\nUm modelo ruim\nfunciona.", [
    ("Dado nulo", "Explode, fica vermelho, alguém é avisado no mesmo dia."),
    ("Modelo ruim", "Devolve número para todo mundo, na faixa certa, sem erro nenhum."),
    ("O resultado", "Pipeline verde, dashboard atualizado, e a lista errada por seis meses.", True),
    ("O teste que ninguém escreve", "O modelo ganha do baseline? Se não ganha, ele não se paga."),
], rodape="8 testes de modelo, que interrompem o job igual aos 11 de ontem.")

linhas("IDEIA 4 · DECISÃO", "Score não é decisão.\nÉ um número\nesperando tradução.", [
    ("O que o modelo entrega", "cliente_id 1847 · score 0,8412. O vendedor não faz nada com isso."),
    ("O que ele precisa", "'Costuma comprar a cada 89 dias e está há 92 sem pedido'"),
    ("Os 35 da lista curta", "'Cliente grande e atrasado para o padrão dele — ligar hoje'", True),
    ("Por que importa", "Modelo que não explica não é usado: fica um mês na tela e some."),
], rodape="E quando ele erra, o motivo é o que permite dizer POR QUE — em vez de perder a confiança.")

# ══════════════════════════════════════════════════════════════════════
#  PARTE 3 · O QUE O DATABRICKS ENTREGA AQUI
# ══════════════════════════════════════════════════════════════════════

linhas("O MODELO NO UNITY CATALOG", "O modelo vira objeto\nde catálogo", [
    ("Do lado das tabelas", "Mesmo catálogo, mesmo GRANT, mesma auditoria. Não é um .pkl no Drive."),
    ("Linhagem completa", "Do CSV que chegou às 6h até a lista de quem o vendedor liga às 8h."),
    ("Alias, não estágio", "@prod e @challenger são apelidos móveis. Promover e reverter é um comando.", True),
    ("Histórico no MLflow", "Um run por treino. 'Por que o número mudou?' vira uma tela, não arqueologia."),
], rodape="Quem consome escreve models:/…@prod e nunca precisa saber o número da versão.")

numeros("A PROVA QUE O COMERCIAL ENTENDE", "O score separa?\n704 clientes que o\nmodelo nunca viu", [
    ("11,7%", "Fria", "compraram nos 30 dias seguintes"),
    ("43,4%", "Morna", "a taxa sobe junto com o score"),
    ("57,8%", "Quente", "sem falar de AUC nenhuma vez"),
    ("81,1%", "Muito quente", "8 em cada 10. Sete vezes a faixa fria"),
])

linhas("BATCH OU TEMPO REAL", "A pergunta muda\numa vez por dia", [
    ("A pergunta da noite", "'Com quem eu falo amanhã de manhã?' Isso não muda a cada clique."),
    ("Endpoint serve para", "Fraude na autorização. Recomendação no carregamento da página. 50ms."),
    ("Aqui seria", "Infraestrutura ligada 24h para responder algo que só muda de manhã.", True),
    ("E, honestamente", "O Free Edition não oferece endpoint próprio. A escolha é técnica E é a conta."),
], rodape="2.816 clientes cabem na memória. Spark serve para o que não cabe.")

linhas("AS ARMADILHAS DO FREE EDITION", "Três que teriam\nquebrado a aula\nao vivo", [
    ("spark_udf não roda", "InvalidVersion: '18.x-aarch64-photon-scala2'. É o caminho que a doc recomenda."),
    ("XGBoost não volta", "Treina, registra, e falha ao carregar. O erro aparece UMA TAREFA depois.", True),
    ("set_experiment", "Não cria a pasta pai. O erro é 'For input string: None' e não fala de pasta."),
    ("DECIMAL em JSON", "A gold usa DECIMAL(18,2). Sem cast para double, o registro do modelo morre."),
], rodape="Todas medidas contra o workspace na preparação. Estão escritas dentro dos prompts.")

# ══════════════════════════════════════════════════════════════════════
#  PARTE 4 · O RETREINO
# ══════════════════════════════════════════════════════════════════════

linhas("O MODELO ENVELHECE", "Retreinar é fácil.\nDecidir é que\nninguém escreve", [
    ("Por que envelhece", "Não é o código que apodrece — é o mundo que muda. E ele não avisa."),
    ("Automático demais", "Todo retreino vira produção. Inclusive o ruim, às 6h de um sábado."),
    ("Manual demais", "Ninguém tem coragem de trocar. Em 2026 o modelo de 2024 ainda decide."),
    ("A saída", "O treino apresenta um @challenger. Uma regra decide, e deixa registro.", True),
], rodape="É code review aplicado a modelo. Ninguém faz merge na main porque passou na sua máquina.")

linhas("A DEMONSTRAÇÃO", "O pipeline recusou\no modelo novo", [
    ("O que aconteceu", "Rodamos de novo. Treinou a versão 2, com AUC idêntico ao da versão 1."),
    ("A decisão", "'Diferença de +0,0000 não passa a margem de 0,01: empate técnico.'", True),
    ("Por que está certo", "Trocar produção por ruído é churn: mais uma versão para explicar, zero de ganho."),
    ("O rollback", "set_registered_model_alias(modelo, 'prod', 1). Uma linha. Nenhum deploy."),
], rodape="A recusa também vira linha na tabela. Metade do valor do histórico está nas recusas.")

# ══════════════════════════════════════════════════════════════════════
#  FECHAMENTO
# ══════════════════════════════════════════════════════════════════════

numeros("O QUE OS 6 PROMPTS ENTREGARAM", "Rodado de ponta\na ponta, seed 42", [
    ("0,8667", "de AUC", "contra 0,6432 da melhor regra simples"),
    ("2.816", "clientes", "pontuados, com faixa e versão do modelo"),
    ("1.290", "contatos", "priorizados por vendedor, com o motivo"),
    ("18", "tarefas", "no mesmo job, com 19 testes que quebram"),
])

divisor("O FECHAMENTO",
        "O algoritmo tem\ntrês linhas e é igual\npara todo mundo",
        "Ciência de dados é saber o que perguntar, com que dado, e ter como provar que a resposta está certa.")

# ══════════════════════════════════════════════════════════════════════
import os
saida = os.path.join(os.path.dirname(os.path.abspath(__file__)),
                     "aula-03-ciencia-de-dados.pptx")
prs.save(saida)
print(f"{len(prs.slides._sldIdLst)} slides → {saida}")
