---

## Fim da noite 3 · confira antes de seguir

```sql
SELECT COUNT(*)                            AS contatos,          -- 200
       COUNT(DISTINCT vendedor)            AS vendedores,        -- 35
       ROUND(SUM(score * ticket_medio), 2) AS receita_esperada   -- 582.799,50
FROM   lakehouse_rotaperfume.gold.fila_semanal;
```

O pipeline tem **15 tarefas**. O modelo `gold.propensao_compra` está no
catálogo com alias `@prod`, e `lift_top200` é **4,25×**.

---

