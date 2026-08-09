-- PREMISAS 3 y 4: lo unico que separa a los canales es el IVA y la devolucion, y
-- la devolucion solo separa si la unidad devuelta NO se revende.
--
-- Cuatro lecturas del mismo margen, todas con transporte 1x por shipment_id:
--
--   cm_reportado   la devolucion no toca ni el ingreso ni el coste (foto del dato)
--   cm_r1          r = 100%: la devolucion resta ingreso y recupera su COGS
--   cm_r0          r = 0%:   la devolucion resta ingreso y el COGS se pierde
--   *_iva_uniforme contrafactual: los cuatro canales al 21%, para aislar cuanto
--                  de la ventaja de wholesale es fiscal y cuanto comercial
--
-- Las dos primeras columnas explican POR QUE la devolucion se cancela con r = 1:
-- si la cesta devuelta tiene el mismo ratio coste/PVP que la vendida, restar
-- ingreso y coste en la misma proporcion deja el margen porcentual intacto.

with n as (
    select shipment_id, count(*) as n_lineas
    from `alohas-recruiting-study-case.production.fct_sale_order_line`
    group by shipment_id
),

j as (
    select
        l.channel,
        l.quantity_sold,
        l.quantity_returned,
        l.gross_sale,
        l.net_sales,
        p.base_price,
        p.cost,
        ifnull(s.shipping_cost, 0) / n.n_lineas as ship
    from `alohas-recruiting-study-case.production.fct_sale_order_line` l
    inner join `alohas-recruiting-study-case.production.dim_product` p using (sku)
    left  join `alohas-recruiting-study-case.production.fct_shipment` s using (shipment_id)
    inner join n on n.shipment_id = l.shipment_id
)

select
    coalesce(channel, 'TODOS')                                                   as canal,

    round(100 * sum(cost * quantity_sold)
              / sum(base_price * quantity_sold), 2)                              as cogs_pvp_cesta_vendida,
    round(100 * sum(cost * quantity_returned)
              / sum(base_price * quantity_returned), 2)                          as cogs_pvp_cesta_devuelta,

    round(100 * sum(net_sales - cost * quantity_sold - ship)
              / sum(net_sales), 2)                                               as cm_reportado,

    round(100 * sum(net_sales * (1 - quantity_returned / quantity_sold)
                    - cost * (quantity_sold - quantity_returned) - ship)
              / sum(net_sales * (1 - quantity_returned / quantity_sold)), 2)     as cm_r1,

    round(100 * sum(net_sales * (1 - quantity_returned / quantity_sold)
                    - cost * quantity_sold - ship)
              / sum(net_sales * (1 - quantity_returned / quantity_sold)), 2)     as cm_r0,

    round(100 * sum(gross_sale * 0.79 * (1 - quantity_returned / quantity_sold)
                    - cost * (quantity_sold - quantity_returned) - ship)
              / sum(gross_sale * 0.79 * (1 - quantity_returned / quantity_sold)), 2)
                                                                                 as cm_r1_iva_uniforme,

    round(100 * sum(gross_sale * 0.79 * (1 - quantity_returned / quantity_sold)
                    - cost * quantity_sold - ship)
              / sum(gross_sale * 0.79 * (1 - quantity_returned / quantity_sold)), 2)
                                                                                 as cm_r0_iva_uniforme,

    round(sum(net_sales * (1 - quantity_returned / quantity_sold)
              - cost * quantity_sold - ship), 0)                                 as contribucion_r0_eur,
    round(sum(net_sales * (1 - quantity_returned / quantity_sold)
              - cost * (quantity_sold - quantity_returned) - ship), 0)           as contribucion_r1_eur
from j
group by rollup (channel)
order by cm_r0 desc
