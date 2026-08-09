-- 04 · Distribucion de lineas por shipment_id, y test del proxy "envio = pedido".
-- Valida [A-02] y la parte empirica de [D-05]: si dentro de un envio todas las
-- lineas comparten fecha y canal, "envio ~ pedido" es defendible y se dice en el
-- report como hallazgo, en vez de preguntarlo.

with por_envio as (
    select
        shipment_id,
        count(*)                                   as lineas,
        count(distinct channel)                    as canales,
        count(distinct date(created_at))           as dias,
        count(distinct sku)                        as skus
    from `alohas-recruiting-study-case.production.fct_sale_order_line`
    group by shipment_id
)

select
    lineas,
    count(*)                                        as envios,
    round(100 * count(*) / sum(count(*)) over (), 2) as pct_envios,
    countif(canales > 1)                            as envios_multicanal,
    countif(dias > 1)                               as envios_multidia,
    countif(skus < lineas)                          as envios_con_sku_repetido
from por_envio
group by lineas
order by lineas
