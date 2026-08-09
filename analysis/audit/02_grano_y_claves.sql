-- 02 · Grano real, duplicados y cardinalidades.
-- Objetivo: poder declarar el grano de cada tabla ("you state your grain" es
-- criterio de evaluacion) y validar [A-02] (si shipment_id se repite entre
-- lineas) antes de decidir el reparto del coste de envio.

with linea as (
    select
        count(*)                                              as filas,
        count(distinct to_json_string(t))                     as filas_distintas,
        count(distinct shipment_id)                           as shipment_ids,
        count(distinct sku)                                   as skus,
        count(distinct channel)                               as canales,
        min(created_at)                                       as primera_venta,
        max(created_at)                                       as ultima_venta
    from `alohas-recruiting-study-case.production.fct_sale_order_line` as t
),

envio as (
    select
        count(*)                    as filas,
        count(distinct shipment_id) as shipment_ids,
        count(distinct country)     as paises,
        count(distinct shipping_method) as metodos
    from `alohas-recruiting-study-case.production.fct_shipment`
),

producto as (
    select
        count(*)              as filas,
        count(distinct sku)   as skus,
        count(distinct category) as categorias
    from `alohas-recruiting-study-case.production.dim_product`
)

select 'fct_sale_order_line' as tabla, 'filas'            as metrica, cast(filas as string)            as valor from linea
union all select 'fct_sale_order_line', 'filas_distintas', cast(filas_distintas as string) from linea
union all select 'fct_sale_order_line', 'shipment_ids',    cast(shipment_ids as string)    from linea
union all select 'fct_sale_order_line', 'skus',            cast(skus as string)            from linea
union all select 'fct_sale_order_line', 'canales',         cast(canales as string)         from linea
union all select 'fct_sale_order_line', 'primera_venta',   cast(primera_venta as string)   from linea
union all select 'fct_sale_order_line', 'ultima_venta',    cast(ultima_venta as string)    from linea
union all select 'fct_shipment',        'filas',           cast(filas as string)           from envio
union all select 'fct_shipment',        'shipment_ids',    cast(shipment_ids as string)    from envio
union all select 'fct_shipment',        'paises',          cast(paises as string)          from envio
union all select 'fct_shipment',        'metodos',         cast(metodos as string)         from envio
union all select 'dim_product',         'filas',           cast(filas as string)           from producto
union all select 'dim_product',         'skus',            cast(skus as string)            from producto
union all select 'dim_product',         'categorias',      cast(categorias as string)      from producto
