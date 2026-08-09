-- PREMISA 2: si los cuatro canales usan la misma mezcla de metodos de envio y
-- agrupan sus lineas en envios del mismo tamano, entonces el criterio de
-- imputacion del transporte les mueve el margen lo mismo a los cuatro y no
-- inclina la balanza hacia ninguno.
--
-- La prueba es la ultima columna: los puntos de margen que separan la cota baja
-- (1x por shipment_id) de la cota alta (coste completo en cada linea). Si esa
-- distancia es la misma para los cuatro canales, la eleccion es inocua.
--
-- Se calcula tambien por categoria para el contraste: ahi si separa.
--
-- El divisor del reparto cuenta TODAS las lineas del envio, incluidas las de SKU
-- huerfano que quedan fuera del mart (D-06).

with n as (
    select shipment_id, count(*) as n_lineas
    from `alohas-recruiting-study-case.production.fct_sale_order_line`
    group by shipment_id
),

j as (
    select
        l.channel,
        p.category,
        l.net_sales,
        ifnull(s.shipping_cost, 0) as ship,
        n.n_lineas
    from `alohas-recruiting-study-case.production.fct_sale_order_line` l
    inner join `alohas-recruiting-study-case.production.dim_product` p using (sku)
    left  join `alohas-recruiting-study-case.production.fct_shipment` s using (shipment_id)
    inner join n on n.shipment_id = l.shipment_id
),

apilado as (
    select 'canal'     as eje, channel  as clave, net_sales, ship, n_lineas from j
    union all
    select 'categoria' as eje, category as clave, net_sales, ship, n_lineas from j
)

select
    eje,
    clave,
    count(*)                                                          as lineas,
    round(avg(net_sales), 2)                                          as neto_por_linea,
    round(avg(n_lineas), 3)                                           as lineas_por_envio,
    round(100 * countif(n_lineas = 1) / count(*), 1)                  as pct_envio_exclusivo,
    round(avg(ship), 3)                                               as tarifa_media_por_linea,
    round(sum(ship / n_lineas), 0)                                    as transporte_1x,
    round(sum(ship), 0)                                               as transporte_completo,
    round(100 * sum(ship / n_lineas) / sum(net_sales), 2)             as pct_ingreso_1x,
    round(100 * sum(ship) / sum(net_sales), 2)                        as pct_ingreso_completo,
    round(100 * (sum(ship) - sum(ship / n_lineas)) / sum(net_sales), 2) as distancia_entre_cotas
from apilado
group by eje, clave
order by eje, lineas desc
