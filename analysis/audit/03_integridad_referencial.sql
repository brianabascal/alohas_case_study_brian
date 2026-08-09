-- 03 · Integridad referencial entre el hecho y sus dos dimensiones.
-- Disparador: 02 revelo 922 SKUs distintos en el hecho contra solo 200 filas en
-- dim_product, y 24.741 shipment_id en el hecho contra 30.000 en fct_shipment.
-- Objetivo: medir cuanta venta se queda sin coste (sin dim_product no hay COGS,
-- o sea no hay contribution margin) y cuanta se queda sin envio.

with linea as (
    select
        l.sku,
        l.shipment_id,
        l.gross_sale,
        p.sku is null as sku_huerfano,
        s.shipment_id is null as envio_huerfano
    from `alohas-recruiting-study-case.production.fct_sale_order_line` as l
    left join `alohas-recruiting-study-case.production.dim_product` as p
        using (sku)
    left join `alohas-recruiting-study-case.production.fct_shipment` as s
        using (shipment_id)
)

select
    'lineas sin producto en dim_product' as problema,
    countif(sku_huerfano)                as filas,
    round(100 * countif(sku_huerfano) / count(*), 2)          as pct_filas,
    round(100 * sum(if(sku_huerfano, gross_sale, 0)) / sum(gross_sale), 2) as pct_gross_sale,
    count(distinct if(sku_huerfano, sku, null))               as skus_afectados
from linea

union all

select
    'lineas sin envio en fct_shipment',
    countif(envio_huerfano),
    round(100 * countif(envio_huerfano) / count(*), 2),
    round(100 * sum(if(envio_huerfano, gross_sale, 0)) / sum(gross_sale), 2),
    count(distinct if(envio_huerfano, shipment_id, null))
from linea

union all

select
    'envios sin ninguna linea de venta',
    count(*),
    null,
    null,
    count(distinct s.shipment_id)
from `alohas-recruiting-study-case.production.fct_shipment` as s
where not exists (
    select 1
    from `alohas-recruiting-study-case.production.fct_sale_order_line` as l
    where l.shipment_id = s.shipment_id
)
