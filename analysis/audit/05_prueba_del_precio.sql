-- 05 · La prueba del precio: se cumple gross_sale = base_price * quantity_sold?
-- Es la query que desambigua tres hipotesis a la vez ([A-04] wholesale a PVP,
-- [A-05] dim_product tipo 1, [A-07] no hay descuentos). Segmentada por canal
-- porque el patron por canal distingue politica comercial de deriva de catalogo.

with base as (
    select
        l.channel,
        l.gross_sale,
        p.base_price * l.quantity_sold as gross_esperado
    from `alohas-recruiting-study-case.production.fct_sale_order_line` as l
    join `alohas-recruiting-study-case.production.dim_product` as p
        using (sku)
)

select
    channel,
    count(*)                                                        as filas,
    countif(abs(gross_sale - gross_esperado) <= 0.01)                as cuadran,
    round(100 * countif(abs(gross_sale - gross_esperado) <= 0.01) / count(*), 2) as pct_cuadran,
    round(avg(safe_divide(gross_sale, gross_esperado)), 4)           as ratio_medio,
    round(min(safe_divide(gross_sale, gross_esperado)), 4)           as ratio_min,
    round(max(safe_divide(gross_sale, gross_esperado)), 4)           as ratio_max,
    countif(safe_divide(gross_sale, gross_esperado) > 1.0001)        as filas_por_encima_de_pvp
from base
group by channel
order by filas desc
