# 🤖 Dia 3: Ciência de dados e agentes | Imersão Jornada de Dados

> **Status parcial:** as três perguntas já estão respondidas **em SQL puro**.
> O modelo e o agente entram ao vivo na quarta, 26/08.

**Promessa da noite:** o dado vira ação.

## 🎯 As três perguntas da diretoria

| # | Arquivo | Pergunta |
|---|---|---|
| 01 | `exemplo-01-quem-vai-comprar-sem-modelo.sql` | Quem vai comprar? |
| 02 | `exemplo-02-quem-esta-sumindo-sem-modelo.sql` | Quem está sumindo? |
| 03 | `exemplo-03-quanto-vamos-vender-sem-modelo.sql` | Quanto vamos vender? |

```bash
python3 scripts/run_sql.py aulas/aula-03-ciencia-de-dados-e-agentes/exemplo-01-quem-vai-comprar-sem-modelo.sql
```

## 💡 Por que começar sem modelo

Cada cliente tem um ritmo de compra. Última compra + ritmo = data provável da
próxima. É uma linha de raciocínio, não um algoritmo — e já responde as três.

Isso não é preguiça: é a **linha de base**. Um modelo só vale a complexidade
que ele custa se bater a régua simples. Sem essa medida, ninguém sabe se o
modelo ajudou.

### O que a régua simples já entrega

| Pergunta | Resposta | Como sabemos que presta |
|---|---|---|
| Quem vai comprar? | 896 clientes na janela de 30 dias, R$ 3.515.297 esperados | Testada contra agosto: **acerta 72,7%**, contra 42,3% de ligar para todos |
| Quem está sumindo? | 69 clientes recuperáveis, R$ 648.694 por trimestre em risco | O corte fixo de 90 dias acusaria 401 — e **231 estão só no ritmo deles** |
| Quanto vamos vender? | out/2026 em R$ 7,4 mi (índice sazonal 1,68) | Prevendo agosto sem olhar para ele, **errou 1,2%** |

## 🔬 O que entra ao vivo

- **Features**: RFM mais sinais de CRM (visita, funil) sobre a gold da noite 2
- **Modelo de propensão**: treino, AUC medido **contra a régua acima**, score versionado
- **O agente**: lê o score e as tabelas, decide o que o vendedor faz hoje —
  e não inventa número, porque só usa ferramenta

## ⚠️ O que o dado sustenta, e o que não

- **Propensão**: use janela de **30 dias** (41% de eventos). Com 90 dias, 81%
  dos clientes compram e o modelo aprende a chutar "sim".
- **Churn**: 6,5% de atrasados é pouco para classificador. Trate como **regra**
  sobre o ritmo e guarde o modelo para a propensão.
- **Previsão**: 24 meses = 2 ciclos, o mínimo. Não há tendência de crescimento
  para extrapolar — projetar alta erra para cima.
