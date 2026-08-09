-- 31 · Un caso real por hallazgo, para poder contarlos con un ejemplo delante
--
-- La auditoria ya midio los agregados. Esto saca la fila concreta que hay detras
-- de cada porcentaje, porque "el 19% de los envios no tiene venta" se entiende a
-- medias y "el paquete SHP-xxxx costo 8,99 EUR y nadie compro nada" se entiende
-- del todo. Alimenta los ejemplos de hallazgos_auditoria.md.

with linea as (
    select * from `alohas-recruiting-study-case.production.fct_sale_order_line`
),
envio as (
    select * from `alohas-recruiting-study-case.production.fct_shipment`
),
producto as (
    select * from `alohas-recruiting-study-case.production.dim_product`
),
lineas_por_envio as (
    select shipment_id, count(*) as n_lineas from linea group by shipment_id
),

-- DQ-02 · ventas que apuntan a un envio que no existe en el libro de envios
dq02 as (
    select
        'DQ-02 venta con envio inexistente' as hallazgo,
        l.shipment_id                       as identificador,
        format('%s · %s · %s · %.2f EUR · el envio no esta en fct_shipment',
               l.channel, l.sku, cast(date(l.created_at) as string), l.gross_sale) as detalle
    from linea l
    left join envio e using (shipment_id)
    where e.shipment_id is null
    order by l.created_at
    limit 2
),

-- DQ-03 · paquetes pagados que ninguna venta reclama
dq03 as (
    select
        'DQ-03 envio huerfano' as hallazgo,
        e.shipment_id          as identificador,
        format('%s a %s · %.2f EUR · ninguna linea de venta lo referencia',
               e.shipping_method, e.country, e.shipping_cost) as detalle
    from envio e
    left join (select distinct shipment_id from linea) r using (shipment_id)
    where r.shipment_id is null
    order by e.shipping_cost desc
    limit 2
),

-- DQ-05 · IVA europeo cobrado a destinos que no lo tienen
dq05 as (
    select
        format('DQ-05 IVA del 21%% con destino %s', e.country) as hallazgo,
        l.shipment_id as identificador,
        format('%s · %s · %.2f EUR de venta y %.2f EUR de impuesto = %.2f%%',
               l.channel, l.sku, l.gross_sale, l.taxes,
               100 * l.taxes / l.gross_sale) as detalle
    from linea l
    join envio e using (shipment_id)
    where e.country in ('US', 'MX')
    order by l.gross_sale desc
    limit 2
),

-- DQ-09 · el porte no depende de lo que va dentro: mismo metodo, mismo precio,
--         tenga el paquete una linea o nueve
dq09 as (
    select
        format('DQ-09 paquete standard con %d linea(s)', n.n_lineas) as hallazgo,
        e.shipment_id as identificador,
        format('%.2f EUR de porte · %d unidades dentro',
               e.shipping_cost,
               (select sum(quantity_sold) from linea x where x.shipment_id = e.shipment_id)) as detalle
    from envio e
    join lineas_por_envio n using (shipment_id)
    where e.shipping_method = 'standard'
      and n.n_lineas in (
          select min(n_lineas) from lineas_por_envio
          union distinct
          select max(n_lineas) from lineas_por_envio n2
          join envio e2 using (shipment_id)
          where e2.shipping_method = 'standard'
      )
    qualify row_number() over (partition by n.n_lineas order by e.shipment_id) = 1
),

-- DQ-10 · el canal no cambia ni el surtido ni el precio: el mismo articulo se
--         vende en los cuatro canales exactamente igual de caro
dq10 as (
    select
        format('DQ-10 el mismo articulo en %s', l.channel) as hallazgo,
        l.sku as identificador,
        format('%s · %s · %.2f EUR por unidad',
               p.name, p.category, l.gross_sale / l.quantity_sold) as detalle
    from linea l
    join producto p using (sku)
    where l.sku = (
        select sku from linea
        group by sku
        having count(distinct channel) = 4
        order by count(*) desc
        limit 1
    )
    qualify row_number() over (partition by l.channel order by l.created_at) = 1
),

-- DQ-11 · el destino tampoco es real: cruzar el Atlantico cuesta lo mismo que
--         cruzar Barcelona
dq11 as (
    select
        format('DQ-11 porte medio next_day a %s', e.country) as hallazgo,
        format('%d envios', count(*)) as identificador,
        format('%.2f EUR de media · cruzar el Atlantico cuesta lo mismo que cruzar Barcelona',
               avg(e.shipping_cost)) as detalle
    from envio e
    where e.shipping_method = 'next_day'
      and e.country in ('ES', 'US')
    group by e.country
),

-- DQ-11 · y el remate: recogida en tienda en paises donde no hay tienda
dq11_pickup as (
    select
        'DQ-11 recogida en tienda fuera de Europa' as hallazgo,
        format('%d envios', count(*)) as identificador,
        format('pickup con destino %s, para una marca que opera desde Barcelona',
               string_agg(distinct e.country order by e.country)) as detalle
    from envio e
    where e.shipping_method = 'pickup'
      and e.country in ('US', 'MX')
),

-- La tarifa media por linea que sale de todo esto, para citarla sin redondear a ojo
tarifa as (
    select
        'REFERENCIA tarifa media de transporte' as hallazgo,
        'D-06' as identificador,
        format('%.2f EUR de pool referenciado / %d lineas = %.4f EUR por linea',
               (select sum(shipping_cost) from envio
                where shipment_id in (select distinct shipment_id from linea)),
               (select count(*) from linea),
               (select sum(shipping_cost) from envio
                where shipment_id in (select distinct shipment_id from linea))
               / (select count(*) from linea)) as detalle
),

-- Cuanto suma la logistica inversa con la convencion de D-21
devoluciones as (
    select
        'REFERENCIA coste total de devoluciones' as hallazgo,
        'D-21' as identificador,
        format('%d lineas con devolucion x %.4f EUR = %.2f EUR (%d unidades devueltas en total)',
               countif(quantity_returned > 0),
               (select sum(shipping_cost) from envio
                where shipment_id in (select distinct shipment_id from linea))
               / (select count(*) from linea),
               countif(quantity_returned > 0) *
               (select sum(shipping_cost) from envio
                where shipment_id in (select distinct shipment_id from linea))
               / (select count(*) from linea),
               sum(quantity_returned)) as detalle
    from linea
)

select * from dq02
union all select * from dq03
union all select * from dq05
union all select * from dq09
union all select * from dq10
union all select * from dq11
union all select * from dq11_pickup
union all select * from tarifa
union all select * from devoluciones
order by hallazgo
