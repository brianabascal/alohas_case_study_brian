-- 11 · Tasa de devolucion por mes de venta.
-- La pregunta que decide si la seccion 02 se puede demostrar o solo argumentar.
-- El dataset esta congelado: tenemos UNA sola version de la tabla, asi que no
-- podemos observar devoluciones llegando. Pero si el generador simulo la llegada
-- tardia, los ultimos meses deberian mostrar una tasa de devolucion mas baja
-- que el resto, no porque se devuelva menos sino porque sus devoluciones aun no
-- habian aterrizado en la fecha de extraccion (2026-05-29).
-- Ese escalon a la derecha ES el sesgo del que avisa el brief, medido con sus
-- propios datos en vez de explicado con palabras.

with por_mes as (
    select
        date_trunc(date(created_at, 'Europe/Madrid'), month)        as mes_venta,
        count(*)                                                    as lineas,
        sum(quantity_sold)                                          as unidades,
        sum(quantity_returned)                                      as devueltas
    from `alohas-recruiting-study-case.production.fct_sale_order_line`
    group by mes_venta
)

select
    mes_venta,
    lineas,
    unidades,
    devueltas,
    round(100 * devueltas / unidades, 2)                     as tasa_devolucion_pct,
    date_diff(date '2026-05-29', mes_venta, day)             as dias_de_madurez
from por_mes
order by mes_venta
