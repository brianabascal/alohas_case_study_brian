-- Prueba de que shipping_cost NO es un coste que escale con el contenido del
-- envio, sino una tarifa fija determinada por el metodo de envio (con ruido
-- uniforme dentro de una banda) e independiente del pais de destino.
--
-- Bloque 1: coste medio por envio segun cuantas lineas cuelgan de el. Si el
--           coste dependiera del contenido, deberia crecer con las lineas.
-- Bloque 2: tarifa por metodo y pais. El metodo lo explica todo; el pais, nada.

with envios as (
    select
        s.shipment_id,
        s.shipping_cost,
        s.shipping_method,
        s.country,
        count(l.sku)         as n_lineas,
        sum(l.quantity_sold) as uds
    from `alohas-recruiting-study-case.production.fct_shipment` s
    left join `alohas-recruiting-study-case.production.fct_sale_order_line` l
        using (shipment_id)
    group by 1, 2, 3, 4
),

coste_vs_contenido as (
    select
        'coste_vs_contenido'            as bloque,
        cast(n_lineas as string)        as clave,
        cast(null as string)            as clave2,
        count(*)                        as envios,
        round(avg(shipping_cost), 2)    as coste_medio,
        round(stddev(shipping_cost), 2) as coste_desv,
        min(shipping_cost)              as coste_min,
        max(shipping_cost)              as coste_max,
        round(avg(uds), 2)              as uds_medias
    from envios
    group by n_lineas
),

tarifa as (
    select
        'tarifa_por_metodo_y_pais'         as bloque,
        ifnull(shipping_method, 'TODOS')   as clave,
        ifnull(country, 'TODOS')           as clave2,
        count(*)                           as envios,
        round(avg(shipping_cost), 2)       as coste_medio,
        round(stddev(shipping_cost), 2)    as coste_desv,
        min(shipping_cost)                 as coste_min,
        max(shipping_cost)                 as coste_max,
        cast(null as float64)              as uds_medias
    from `alohas-recruiting-study-case.production.fct_shipment`
    group by rollup(shipping_method, country)
)

select * from coste_vs_contenido
union all
select * from tarifa
order by bloque, clave, clave2
