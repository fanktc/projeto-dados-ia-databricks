# Noite 1 · Roteiro do Genie (ambiente 3)

Não é preciso criar um Genie Space: o `genie ask` da CLI já responde sobre o
catálogo governado. Rode do terminal, com a tela compartilhada.

```bash
databricks genie ask "<pergunta>" --include-sql --profile projeto-dados-ia
```

O `--include-sql` é o que faz a demonstração valer: a turma vê o SQL que o
Genie escreveu, não só a resposta.

## Pergunta 1 — a pergunta da noite (funciona)

> Qual foi a receita total dos pedidos não cancelados na tabela
> rota_perfume.bronze.pedidos?

Resposta obtida: **R$ 102.303.828,05** — o mesmo número do SQL escrito à mão e
do `n1_receita.py`. Três ferramentas, um número.

Dois detalhes que valem apontar na tela:

1. O Genie **primeiro rodou `SELECT DISTINCT status`** para descobrir quais
   status existem antes de filtrar. Ele explorou o dado, não chutou.
2. O resultado bruto saiu como `1.0230382804999976E8`. Ele usou
   `CAST(valor_total AS DOUBLE)` — é o mesmo ruído de ponto flutuante que a
   gente evita com `DECIMAL(18,2)` no SQL da noite.

## Pergunta 2 — a que depende do dado limpo

> Quantos clientes únicos existem em rota_perfume.bronze.clientes considerando
> o CNPJ? Cuidado que o mesmo CNPJ pode estar escrito de formas diferentes.

Resposta obtida: **3.000 clientes únicos** para 3.040 registros — e o Genie
ainda mostrou a comparação: 3.024 CNPJs distintos sem normalizar contra 3.000
normalizando.

**Ele acertou.** Mas repare *por que* acertou: porque a pergunta já continha o
aviso. Faça a mesma pergunta sem a segunda frase e veja o que sai.

É esse o fecho da noite: o Genie foi o ambiente mais confortável dos quatro,
e mesmo assim só chegou no número certo porque quem perguntou sabia que o
CNPJ vinha em três formatos. Ele não descobre a sujeira — ele contorna, quando
avisado.

> Engenharia de dados não é o que a IA substitui. É o que faz a IA funcionar.

## Se quiser um Genie Space de verdade

`databricks genie create-space` exige um `serialized_space` em JSON, que só se
obtém exportando um espaço existente (`genie get-space`). Para a noite 1 o
`genie ask` entrega a mesma demonstração sem esse trabalho. O Space curado,
com instruções e exemplos de query, faz mais sentido depois da silver — quando
existir dado limpo para ele apontar.
