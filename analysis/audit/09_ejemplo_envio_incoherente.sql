-- 09 · Casos concretos de envios imposibles.
-- Objetivo: bajar el hallazgo [DQ-04] de porcentaje a ejemplo. Un shipment_id
-- deberia representar una caja que sale del almacen; si sus lineas estan
-- separadas por meses y son de canales distintos, no representa nada fisico.

select
    shipment_id,
    count(*)                                                          as lineas,
    min(date(created_at))                                             as primera_linea,
    max(date(created_at))                                             as ultima_linea,
    date_diff(max(date(created_at)), min(date(created_at)), day)      as dias_de_separacion,
    string_agg(distinct channel order by channel)                     as canales_mezclados
from `alohas-recruiting-study-case.production.fct_sale_order_line`
group by shipment_id
having count(*) > 1
order by dias_de_separacion desc
limit 5
