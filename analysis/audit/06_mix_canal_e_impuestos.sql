-- 06 · Mix de canal, coherencia de net_sales y tipo impositivo efectivo.
-- Dos objetivos: (a) confirmar que net_sales = gross_sale - taxes, que es la
-- premisa de la escalera de ingresos; (b) medir el tipo efectivo por canal, que
-- es lo que rompe la comparabilidad like-for-like de la pregunta 01.
-- El mix de canal ademas es el que hay que usar para juzgar si el agrupamiento
-- por shipment_id es o no compatible con una asignacion aleatoria.

select
    channel,
    count(*)                                                   as filas,
    round(100 * count(*) / sum(count(*)) over (), 2)           as pct_filas,
    sum(quantity_sold)                                         as unidades,
    sum(quantity_returned)                                     as unidades_devueltas,
    round(100 * sum(quantity_returned) / sum(quantity_sold), 2) as pct_devolucion,
    round(sum(gross_sale), 0)                                  as gross_sale,
    round(100 * sum(taxes) / sum(gross_sale), 2)               as tipo_efectivo_pct,
    countif(abs(net_sales - (gross_sale - taxes)) > 0.01)      as filas_net_sales_incoherente,
    countif(quantity_returned > quantity_sold)                 as filas_devuelve_mas_de_lo_vendido,
    countif(quantity_sold <= 0)                                as filas_cantidad_no_positiva
from `alohas-recruiting-study-case.production.fct_sale_order_line`
group by channel
order by filas desc
