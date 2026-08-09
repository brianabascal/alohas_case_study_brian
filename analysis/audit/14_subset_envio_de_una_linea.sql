-- Representatividad del subconjunto de lineas cuyo shipment_id no esta
-- compartido con ninguna otra linea.
--
-- Es el unico subconjunto donde el vinculo linea <-> envio no queda desmentido
-- por la evidencia de DQ-04 (envios que abarcan dias distintos). La pregunta es
-- si sirve como poblacion del report o solo como conjunto de control: para eso
-- hay que saber si esta sesgado respecto al resto.

with j as (
    select
        l.channel,
        l.quantity_sold,
        l.quantity_returned,
        l.gross_sale,
        l.created_at,
        s.shipping_cost,
        count(*) over (partition by l.shipment_id) as n_lineas
    from `alohas-recruiting-study-case.production.fct_sale_order_line` l
    left join `alohas-recruiting-study-case.production.fct_shipment` s
        using (shipment_id)
),

etiquetado as (
    select *, if(n_lineas = 1, 'subset_1_linea', 'resto') as grupo
    from j
    where shipping_cost is not null
)

select
    ifnull(grupo, 'TOTAL')                                          as grupo,
    count(*)                                                        as lineas,
    round(100 * countif(channel = 'online')      / count(*), 1)     as pct_online,
    round(100 * countif(channel = 'retail')      / count(*), 1)     as pct_retail,
    round(100 * countif(channel = 'wholesale')   / count(*), 1)     as pct_wholesale,
    round(100 * countif(channel = 'marketplace') / count(*), 1)     as pct_marketplace,
    round(avg(quantity_sold), 3)                                    as uds_por_linea,
    round(100 * sum(quantity_returned) / sum(quantity_sold), 2)     as tasa_devolucion_pct,
    round(avg(gross_sale), 2)                                       as gross_por_linea,
    round(sum(gross_sale), 0)                                       as gross_total,
    round(avg(shipping_cost), 2)                                    as coste_envio_medio,
    min(date(created_at))                                           as desde,
    max(date(created_at))                                           as hasta
from etiquetado
group by rollup(grupo)
order by grupo
