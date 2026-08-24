"""Exemplo 05 · Modelo de propensão — e a régua que ele precisa bater.

Conceito: split temporal, baseline honesto, AUC, importância de variável
Pergunta de negócio: o modelo ajuda mais que a regra simples do exemplo 01?

A pergunta acima é a única que importa. Um modelo com AUC 0,85 parece ótimo
até alguém perguntar quanto a regra de uma linha já entregava — e descobrir
que era quase o mesmo.

Por isso este script começa medindo a régua, e só depois treina.

    cd aulas/aula-04-deploy/perfumesarabe
    .venv/bin/python ../../aula-03-ciencia-de-dados-e-agentes/exemplo-05-modelo-propensao.py

Precisa de: databricks-connect, scikit-learn, pandas.
"""

import sys

import pandas as pd
from sklearn.ensemble import HistGradientBoostingClassifier
from sklearn.dummy import DummyClassifier
from sklearn.metrics import roc_auc_score, precision_score, recall_score
from sklearn.model_selection import train_test_split

CATALOGO = "rota_perfume"

# Colunas que descrevem o cliente. Repare que nenhuma delas olha para o
# futuro: todas foram calculadas até a data de referência no exemplo 04.
FEATURES = [
    "recencia_dias", "frequencia", "pedidos_90d", "valor_total", "ticket_medio",
    "ticket_desvio", "dias_de_relacionamento", "ritmo_dias", "ritmo_desvio",
    "atraso_relativo", "visitas_90d", "taxa_conversao_visita", "dias_ultima_visita",
    "oport_abertas", "valor_no_funil", "taxa_ganho_historica",
    "categorias_compradas", "marcas_compradas", "margem_media",
]
ALVO = "comprou_em_30d"


def carregar() -> pd.DataFrame:
    from databricks.connect import DatabricksSession

    spark = DatabricksSession.builder.getOrCreate()
    df = spark.table(f"{CATALOGO}.gold.features_cliente").toPandas()
    print(f"features: {len(df):,} clientes · alvo positivo em {100*df[ALVO].mean():.1f}%\n")
    return df


def regua_simples(df: pd.DataFrame) -> pd.Series:
    """A régua do exemplo 01, escrita como previsão binária.

    'Vai comprar se a próxima compra prevista cai dentro dos próximos 30 dias'
    equivale a: já passou de (ritmo - 30) dias desde a última compra.
    """
    return (df["recencia_dias"] >= (df["ritmo_dias"] - 30)).astype(int)


def avaliar(nome: str, y, previsto, probabilidade=None) -> dict:
    m = {
        "modelo": nome,
        "precisao": precision_score(y, previsto, zero_division=0),
        "recall": recall_score(y, previsto, zero_division=0),
        "auc": roc_auc_score(y, probabilidade) if probabilidade is not None else float("nan"),
    }
    auc = f"{m['auc']:.3f}" if m["auc"] == m["auc"] else "  —  "
    print(f"  {nome:<28} precisão {m['precisao']:.3f}   recall {m['recall']:.3f}   AUC {auc}")
    return m


def main() -> None:
    df = carregar()
    X, y = df[FEATURES].fillna(0), df[ALVO]

    # Split estratificado: o mesmo percentual de compradores nos dois lados.
    X_tr, X_te, y_tr, y_te, idx_tr, idx_te = train_test_split(
        X, y, df.index, test_size=0.3, random_state=42, stratify=y
    )
    print(f"treino {len(X_tr):,} · teste {len(X_te):,}\n")

    print("Como ler: quem vence não é quem tem AUC maior, é quem te ajuda a\n"
          "escolher melhor as 20 ligações do dia.\n")

    # ── 1. o chão: chutar sempre 'sim' ──────────────────────────────────
    burro = DummyClassifier(strategy="constant", constant=1).fit(X_tr, y_tr)
    avaliar("chutar sim para todos", y_te, burro.predict(X_te))

    # ── 2. a régua do exemplo 01, sem treino nenhum ─────────────────────
    avaliar("régua: ritmo de compra", y_te, regua_simples(df.loc[idx_te]))

    # ── 3. o modelo ─────────────────────────────────────────────────────
    modelo = HistGradientBoostingClassifier(
        max_iter=200, learning_rate=0.08, max_depth=5, random_state=42
    ).fit(X_tr, y_tr)
    prob = modelo.predict_proba(X_te)[:, 1]
    m = avaliar("modelo (gradient boosting)", y_te, modelo.predict(X_te), prob)

    # ── o que o modelo aprendeu ─────────────────────────────────────────
    from sklearn.inspection import permutation_importance

    imp = permutation_importance(modelo, X_te, y_te, n_repeats=5, random_state=42)
    ordem = imp.importances_mean.argsort()[::-1][:8]
    print("\n  As 8 variáveis que mais pesam:")
    for i in ordem:
        print(f"    {FEATURES[i]:<26} {imp.importances_mean[i]:.4f}")

    print("\n  Se 'atraso_relativo' e 'ritmo_dias' lideram, o modelo redescobriu\n"
          "  a régua do exemplo 01 — e o ganho dele vem do ajuste fino, não de\n"
          "  uma ideia nova.")

    # ── grava o score para todo mundo ───────────────────────────────────
    from databricks.connect import DatabricksSession

    spark = DatabricksSession.builder.getOrCreate()
    df["score_propensao"] = modelo.predict_proba(X)[:, 1]
    df["faixa"] = pd.cut(
        df["score_propensao"], [0, 0.3, 0.6, 0.8, 1.0],
        labels=["Fria", "Morna", "Quente", "Muito quente"], include_lowest=True,
    ).astype(str)

    saida = df[["cliente_id", "data_referencia", "score_propensao", "faixa", ALVO]]
    (spark.createDataFrame(saida)
        .withColumn("calculado_em", __import__("pyspark").sql.functions.current_timestamp())
        .write.format("delta").mode("overwrite").option("overwriteSchema", "true")
        .saveAsTable(f"{CATALOGO}.gold.score_propensao"))

    print(f"\n  gravado: {CATALOGO}.gold.score_propensao ({len(saida):,} clientes)")
    print(f"  AUC do modelo: {m['auc']:.3f}")


if __name__ == "__main__":
    sys.exit(main())
