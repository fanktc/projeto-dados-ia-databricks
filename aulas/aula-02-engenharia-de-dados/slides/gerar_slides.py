#!/usr/bin/env python3
"""Gera os slides da Noite 2 — no mesmo sistema de design da Noite 1.

Slide também é código. Os tokens abaixo foram extraídos do deck
"Lançamento Agosto - Jornada de dados - v1 - Aula 01.pptx", então este arquivo
e aquele desenham a mesma coisa.

Uso:  python gerar_slides.py            (precisa de python-pptx)
Saída: aula-02-engenharia-de-dados.pptx
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


def texto(s, txt, x, y, w, h, tam, cor, negrito=False, alinha=PP_ALIGN.LEFT, entrelinha=1.0):
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
        r.font.name = "Arial"
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
    texto(s, linha, 2.8, 15.4, 32.0, 2.4, 60, CINZA)
    return s


# ── arquétipo 2: linhas em card ───────────────────────────────────────
def linhas(chapeu, titulo, itens, rodape=None):
    """itens: lista de (rotulo, corpo) ou (rotulo, corpo, destaque)."""
    s = nova()
    texto(s, chapeu, 1.8, 1.8, 32.0, 1.12, 44, ACENTO, True)
    texto(s, titulo, 1.8, 3.5, 36.4, 4.4, 128, BRANCO, True, entrelinha=0.95)

    topo, altura, folga = 8.17, 3.02, 0.42
    if len(itens) == 4:
        altura, folga = 2.55, 0.34
    for i, item in enumerate(itens):
        rotulo, corpo = item[0], item[1]
        destaque = len(item) > 2 and item[2]
        y = topo + i * (altura + folga)
        caixa(s, 1.77, y, 36.46, altura, destaque)
        texto(s, rotulo, 3.0, y + 0.55, 10.4, altura, 62 if len(itens) < 4 else 54,
              ACENTO if destaque else BRANCO, True)
        texto(s, corpo, 13.8, y + 0.55, 23.2, altura, 50 if len(itens) < 4 else 44,
              CINZA, entrelinha=1.05)
    if rodape:
        texto(s, rodape, 1.8, 19.0, 36.0, 1.6, 50, ACENTO_CLR)
    assinatura(s)
    return s


# ── arquétipo 3: quatro números ───────────────────────────────────────
def numeros(chapeu, titulo, tiles):
    """tiles: lista de (simbolo, valor, descricao), até 4."""
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


# ══════════════════════════════════════════════════════════════════════
#  A NOITE
# ══════════════════════════════════════════════════════════════════════

# ── abertura ──────────────────────────────────────────────────────────
divisor("NOITE 2 · TERÇA 25/08",
        "Engenharia de dados:\no projeto passa\na rodar sozinho",
        "Ontem vocês clicaram. Hoje a gente constrói — e o que a gente constrói continua rodando.")

linhas("DE ONTEM PARA HOJE", "O que muda esta noite", [
    ("Ontem", "Vocês subiram as 10 tabelas clicando, uma por uma. Se o dado atualizar, refaz tudo."),
    ("Ontem", "A query do exemplo 04 QUEBROU, ao vivo, por causa das datas em dois formatos."),
    ("Ontem", "O Genie foi plugado na bronze com o aviso: pode dar certo, pode dar errado."),
    ("Hoje", "Cada uma dessas três coisas vira um prompt — e a resposta fica de pé sozinha.", True),
], rodape="Engenharia de dados não é escrever SQL bonito. É fazer o problema parar de voltar.")

linhas("O FORMATO DA NOITE", "6 prompts, 6 deploys", [
    ("Um bundle", "Ele nasce vazio no prompt 1 e ganha uma camada por prompt. Nada aparece pronto."),
    ("Um job", "Começa com UMA tarefa e termina com DOZE. O DAG crescendo é a tela da noite."),
    ("Seis deploys", "Deploy não é etapa de fim de projeto. É o que acontece toda vez que você termina algo.", True),
], rodape="raw → bronze → silver → gold → dashboard → agentes de IA")

# ── prompt 1 ──────────────────────────────────────────────────────────
divisor("PROMPT 1", "Raw", "O catálogo vira código, e o dado chega ao Volume.")

linhas("PROMPT 1 · O CONCEITO", "Raw não é bronze", [
    ("Raw", "É ARQUIVO. O CSV como o ERP mandou, byte por byte. É a prova."),
    ("Bronze", "É TABELA. Delta, consultável, com metadado de ingestão."),
    ("Volume", "Objeto do Unity Catalog: tem dono, tem permissão, aparece na linhagem. DBFS é uma pasta sem sobrenome.", True),
], rodape="Ontem: Create catalog, Create schema, três vezes. Hoje: trinta linhas de YAML.")

numeros("PROMPT 1 · O QUE FICOU DE PÉ", "Primeiro deploy", [
    ("10", "arquivos", "ERP e CRM no Volume bronze.raw, 14,7 MB"),
    ("313.551", "linhas", "conferidas uma a uma na chegada"),
    ("1", "tarefa", "raw_conferencia, que QUEBRA se faltar arquivo"),
    ("↻", "reproduzível", "apagou? um deploy traz de volta idêntico"),
])

# ── prompt 2 ──────────────────────────────────────────────────────────
divisor("PROMPT 2", "Bronze", "Dez tabelas em um comando — a resposta direta à noite de ontem.")

linhas("PROMPT 2 · A DECISÃO", "Por que tudo entra como texto", [
    ("Se inferir tipo", "15/10/2025 vira NULO e o CNPJ perde os zeros à esquerda. São 309 registros."),
    ("A sujeira sumiria", "Antes de vocês verem que ela existiu. E ninguém saberia se o erro veio da origem ou da limpeza."),
    ("A bronze é a prova", "Ela preserva o problema para que ele possa ser resolvido — não escondido. E nunca se edita.", True),
], rodape="Duas colunas a mais, só: _ingerido_em e _arquivo_origem. Quando entrou, e de onde veio.")

# ── prompt 3 ──────────────────────────────────────────────────────────
divisor("PROMPT 3", "Silver", "A limpeza com contrato. A entrega mais importante da noite.")

linhas("PROMPT 3 · A DECISÃO DA NOITE", "Quantidade negativa\né devolução", [
    ("Descartar a linha", "Esconde receita negativa e INFLA o faturamento. O diretor comemora um número errado."),
    ("Manter sem flag", "Polui toda soma que alguém fizer daqui para frente."),
    ("Sinalizar e manter", "Correto. Quem analisa decide se quer o bruto ou o líquido — e os dois reconciliam.", True),
], rodape="São 2.327 itens. A escolha entre as três muda o número que a diretoria vê.")

linhas("PROMPT 3 · O CONTRATO", "A constraint que\nestava errada", [
    ("A regra óbvia", "valor_liquido >= 0. Parece certa. FALHOU em 135 pedidos."),
    ("A investigação", "Os 135 têm item devolvido: o saldo do pedido virou negativo. Negócio legítimo."),
    ("A lição", "A regra errada era a nossa, não o dado. A constraint virou suposição em pergunta — antes de virar número no dashboard.", True),
], rodape="CONSTRAINT não é comentário: o Delta passa a RECUSAR a escrita que violar a regra.")

# ── prompt 4 ──────────────────────────────────────────────────────────
divisor("PROMPT 4", "Gold", "Dimensões, fato, marts por diretoria — e os testes que quebram o pipeline.")

linhas("PROMPT 4 · O CONTRATO VEM ANTES DO SQL", "Um fato, vários marts", [
    ("O erro clássico", "Um fato por área. Em três meses eles divergem e ninguém sabe qual está certo."),
    ("O que separa", "A DIMENSÃO DOMINANTE e as MÉTRICAS. Nunca a tabela base."),
    ("Conformado", "Vendas, Produto e Financeiro somam EXATAMENTE o mesmo R$ 102.303.828,05.", True),
], rodape="Se você não consegue escrever o contrato numa frase, você ainda não sabe o que está construindo.")

numeros("PROMPT 4 · O QUE A GOLD ENTREGA", "E o teste que\nmais importa", [
    ("R$", "102.303.828,05", "receita na gold — idêntica à silver e à noite 1"),
    ("191.080", "linhas", "no fato, grão de item de pedido"),
    ("40,2%", "de margem", "Kit Presente 33,0% · Óleo Concentrado 49,9%"),
    ("9", "testes", "que QUEBRAM o job. Teste que não quebra é relatório"),
])

# ── prompt 5 ──────────────────────────────────────────────────────────
divisor("PROMPT 5", "Dashboard", "Como código. Versionado, com diff e com rollback.")

linhas("PROMPT 5 · O QUE QUASE NINGUÉM ENSINA", "Dashboard também\né artefato", [
    ("Clicado", "Não tem diff, não tem revisão, não tem rollback. Se alguém apaga, acabou."),
    ("Em JSON no Git", "Sobe junto com o deploy. Desfazer é git revert."),
    ("Métrica uma vez", "Com MEASURE(), receita é definida num lugar só. Nenhuma tela mostra número diferente da outra.", True),
], rodape="Ontem o dataset tinha CAST e dois try_to_date. Hoje é `receita`. Metade do SQL — é o que a silver comprou.")

# ── prompt 6 ──────────────────────────────────────────────────────────
divisor("PROMPT 6", "Agentes de IA", "O mesmo dado, outra porta. E o fechamento do arco da noite 1.")

linhas("PROMPT 6 · O QUE FAZ A IA FUNCIONAR", "Metadado é interface", [
    ("COMMENT", "Não é documentação para humano ler. É o que o agente lê para DECIDIR qual coluna usar."),
    ("View de negócio", "Ninguém pergunta por fato_vendas. Perguntam por ranking de marcas e clientes em risco."),
    ("Regra de negócio", "O modelo não adivinha que dezembro é vale POR DESENHO do setor. Alguém precisa escrever.", True),
], rodape="Coluna sem comentário é coluna que o Genie vai usar errado — com confiança.")

numeros("PROMPT 6 · O CLÍMAX", "A mesma pergunta\nde ontem", [
    ("1", "Marcas", "\"Quais mais venderam?\" — ele acerta, como ontem"),
    ("2", "Churn", "\"Quem sumiu e quanto perdemos?\" — 503 clientes, R$ 836 mil/mês"),
    ("3", "Sazonalidade", "\"Dezembro foi ruim?\" — ele responde NÃO. É vale de setor"),
    ("=", "Mesmo modelo", "Mudou o que está embaixo dele: duas horas de engenharia"),
])

# ── fechamento ────────────────────────────────────────────────────────
linhas("FIM DA NOITE 2", "O que você tem agora", [
    ("Catálogo como código", "Três schemas, um Volume, 10 tabelas bronze, 10 silver, 4 dimensões, 1 fato, 3 marts e 6 views."),
    ("Um job de 12 tarefas", "Agendado, com dependência explícita e 11 testes que interrompem se um número mudar."),
    ("Dashboard e Genie", "Os dois versionados no bundle. Se apagar, um deploy traz de volta."),
    ("Tudo de seis prompts", "A partir de um catálogo vazio. E existe um script que apaga tudo, para você provar isso.", True),
])

divisor("O FECHAMENTO",
        "Engenharia de dados\nnão é o que a IA\nsubstitui",
        "É o que faz a IA funcionar. Amanhã: as três perguntas da diretoria viram modelo.")

# ══════════════════════════════════════════════════════════════════════
import os
saida = os.path.join(os.path.dirname(os.path.abspath(__file__)),
                     "aula-02-engenharia-de-dados.pptx")
prs.save(saida)
print(f"{len(prs.slides.__iter__.__self__._sldIdLst)} slides → {saida}")
