---

## Fim da noite 2 · confira antes de seguir

```sql
SELECT COUNT(*) AS linhas, ROUND(SUM(receita), 2) AS receita
FROM   lakehouse_rotaperfume.gold.fato_vendas;
-- 191.080 linhas · R$ 102.303.828,05
```

O pipeline tem **12 tarefas** e roda verde de ponta a ponta. Se este número não
bater, não adianta seguir: a noite 3 treina em cima dele.

---

