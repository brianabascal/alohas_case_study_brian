-- PREMISA 1: los cuatro canales venden lo mismo, al mismo precio y con el mismo
-- coste de produccion.
--
-- Se miden las tres magnitudes que determinan el margen antes de impuestos y
-- devoluciones: unidades por linea, PVP y COSTE. Junto a cada media va su error
-- estandar, para poder afirmar "indistinguible" en vez de "parecido": si la
-- diferencia entre dos canales cabe dentro de 2 errores estandar, no hay senal,
-- solo ruido muestral.
--
-- Excluye SKUs huerfanos (inner join), en linea con D-09: sin ficha de producto
-- no hay coste que comparar.

select
    coalesce(l.channel, 'TODOS')                                          as canal,
    count(*)                                                              as lineas,
    count(distinct l.sku)                                                 as skus_distintos,
    round(avg(l.quantity_sold), 4)                                        as uds_por_linea,
    round(avg(l.gross_sale), 2)                                           as pvp_por_linea,
    round(stddev(l.gross_sale) / sqrt(count(*)), 2)                       as ee_pvp_por_linea,
    round(avg(p.cost * l.quantity_sold), 2)                               as cogs_por_linea,
    round(stddev(p.cost * l.quantity_sold) / sqrt(count(*)), 2)           as ee_cogs_por_linea,
    round(avg(p.base_price), 2)                                           as pvp_medio_articulo,
    round(avg(p.cost), 2)                                                 as cogs_medio_articulo,
    round(100 * sum(p.cost * l.quantity_sold)
              / sum(p.base_price * l.quantity_sold), 2)                   as cogs_sobre_pvp_pct,
    round(100 * sum(l.taxes) / sum(l.gross_sale), 2)                      as tipo_impositivo_pct,
    round(100 * sum(l.quantity_returned) / sum(l.quantity_sold), 2)       as tasa_devolucion_pct
from `alohas-recruiting-study-case.production.fct_sale_order_line` l
inner join `alohas-recruiting-study-case.production.dim_product` p using (sku)
group by rollup (l.channel)
order by lineas desc
