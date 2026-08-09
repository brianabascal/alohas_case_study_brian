-- 29 · Cuanto gana de verdad cada canal, y cuanto ganaria en el mundo real
--
-- Sustituye a 18_bloques_para_escenarios.sql + 19_escenarios_y_umbrales.py, que
-- calculaban umbrales de rentabilidad y ademas restaban el transporte con el
-- modelo viejo (1x por shipment_id), descartado en D-06.
--
-- Reglas de calculo, todas escritas en las decisiones:
--
--   Transporte (D-06): el pool son los envios que alguna venta referencia, y se
--   reparte a partes iguales entre las 50.000 lineas. Ni se agrupa por
--   shipment_id ni se hereda el metodo: la auditoria demostro que ese vinculo es
--   ruido. Los envios huerfanos quedan fuera del pool.
--
--   Devolucion (D-19 + D-21): la prenda devuelta no se revende, asi que su coste
--   de produccion se pierde entero. Traerla de vuelta cuesta lo mismo que costo
--   enviarla, y se cobra UNA vez por linea aunque el cliente devuelva tres
--   prendas de esa linea.
--
--   SKUs sin ficha (D-09): fuera, porque sin coste de producto no hay margen que
--   calcular. Siguen contando en el divisor del transporte.
--
-- Tres lecturas del margen observado, que son la escalera de la seccion 5:
--   cm_observado          la foto del dato tal cual
--   cm_iva_igualado       los cuatro canales pagando el 21%, para ver cuanta
--                         ventaja de wholesale es puramente fiscal
--   cm_sin_devolucion     ademas, la devolucion sin efecto economico; lo que
--                         quede de diferencia ya no lo explica nada
--
-- Y una cuarta, el escenario que pidio Alohas: wholesale facturando al 45% del
-- PVP (precio real de mayorista en moda) y marketplace pagando un 17,5% de
-- comision sobre lo que cobra al cliente final.

with tarifa as (
    select
        (
            select sum(s.shipping_cost)
            from `alohas-recruiting-study-case.production.fct_shipment` s
            where s.shipment_id in (
                select distinct shipment_id
                from `alohas-recruiting-study-case.production.fct_sale_order_line`
            )
        )
        / (select count(*) from `alohas-recruiting-study-case.production.fct_sale_order_line`)
        as eur_por_linea
),

linea as (
    select
        l.channel,
        l.quantity_returned,

        -- Lo que queda del ingreso despues de descontar lo devuelto.
        l.net_sales * (1 - l.quantity_returned / l.quantity_sold)   as ingreso,

        -- Contrafactual fiscal: mismo importe de escaparate, IVA del 21% para todos.
        l.gross_sale * 0.79 * (1 - l.quantity_returned / l.quantity_sold) as ingreso_iva_igualado,

        p.cost * l.quantity_sold                                    as coste_producto,
        p.cost * (l.quantity_sold - l.quantity_returned)            as coste_producto_si_se_revendiera,

        t.eur_por_linea                                             as transporte,
        if(l.quantity_returned > 0, t.eur_por_linea, 0)             as coste_devolucion,

        -- Escenario: el mayorista no paga precio de escaparate, y el marketplace
        -- se queda su comision de lo que le cobra al cliente final.
        l.net_sales * (1 - l.quantity_returned / l.quantity_sold)
            * if(l.channel = 'wholesale', 0.45, 1.0)                as ingreso_escenario,
        if(l.channel = 'marketplace',
           0.175 * l.gross_sale * (1 - l.quantity_returned / l.quantity_sold),
           0)                                                       as comision
    from `alohas-recruiting-study-case.production.fct_sale_order_line` l
    inner join `alohas-recruiting-study-case.production.dim_product` p using (sku)
    cross join tarifa t
)

select
    coalesce(channel, 'TODOS')                                      as canal,

    count(*)                                                        as lineas,
    countif(quantity_returned > 0)                                  as lineas_con_devolucion,

    round(sum(ingreso), 0)                                          as ingreso_neto_eur,
    round(sum(coste_producto), 0)                                   as coste_producto_eur,
    round(sum(transporte), 0)                                       as transporte_eur,
    round(sum(coste_devolucion), 0)                                 as devolucion_eur,

    -- 1. La foto del dato
    round(sum(ingreso - coste_producto - transporte - coste_devolucion), 0)
                                                                    as contribucion_eur,
    round(100 * sum(ingreso - coste_producto - transporte - coste_devolucion)
              / sum(ingreso), 2)                                    as cm_observado,

    -- 2. Igualando el IVA al 21% en los cuatro canales
    round(100 * sum(ingreso_iva_igualado - coste_producto - transporte - coste_devolucion)
              / sum(ingreso_iva_igualado), 2)                       as cm_iva_igualado,

    -- 3. Y ademas sin ningun efecto de la devolucion: la prenda que vuelve
    --    recupera su coste de produccion y no cuesta nada traerla
    round(100 * sum(ingreso_iva_igualado - coste_producto_si_se_revendiera - transporte)
              / sum(ingreso_iva_igualado), 2)                       as cm_sin_devolucion,

    -- 4. El escenario: wholesale al 45% del PVP, marketplace al -17,5% de comision
    round(sum(ingreso_escenario - coste_producto - transporte - coste_devolucion - comision), 0)
                                                                    as contribucion_escenario_eur,
    round(100 * sum(ingreso_escenario - coste_producto - transporte - coste_devolucion - comision)
              / sum(ingreso_escenario), 2)                          as cm_escenario
from linea
group by rollup (channel)
order by cm_observado desc
