-- Grano: una línea de pedido.
--
-- Aquí, y solo aquí, se aplican las dos reglas que gobiernan toda la sección 01:
-- la conversión horaria a Europe/Madrid (D-17) y la escalera de ingresos (D-15).
-- Los modelos de arriba ya no vuelven a tocar esa lógica.
with linea as (
    select * from {{ ref('stg_fct_sale_order_line') }}
),

producto as (
    select * from {{ ref('stg_dim_product') }}
),

enriquecida as (
    select
        l.sale_order_line_sk,
        l.channel,
        l.sku,
        p.category,

        -- DQ-01: 750 líneas venden artículos que no están en el catálogo. Son
        -- ventas reales y cuentan como ingreso, pero no tienen coste, así que la
        -- sección 03 las dejará fuera del margen (D-09). El flag permite declarar
        -- esa diferencia en vez de que aparezca como un descuadre.
        p.sku is not null as is_catalog_product,

        -- Las fechas vienen en UTC y Alohas cierra sus meses desde Barcelona.
        l.created_at as created_at_utc,
        cast(
            (l.created_at at time zone 'UTC') at time zone 'Europe/Madrid' as date
        ) as sale_date,

        l.quantity_sold,
        l.quantity_returned,

        -- Peldaño 1: lo que se cobró al cliente, con el impuesto dentro.
        l.gross_sale as gross_charged,
        l.taxes,

        -- Peldaño 2: el campo `net_sales` del dataset NO es neto de devoluciones,
        -- es la venta menos el impuesto. El nombre engaña, así que se renombra.
        l.net_sales as revenue_ex_tax,

        -- Peldaño 3: la parte del ingreso que el cliente se llevó de vuelta. El
        -- nullif es defensivo: assert_quantities_are_coherent ya falla si alguna
        -- línea trae quantity_sold = 0, pero el modelo no debe depender del test.
        cast(
            round(
                l.net_sales * l.quantity_returned / nullif(l.quantity_sold, 0), 2
            ) as decimal(18, 2)
        ) as returned_revenue

    from linea as l
    left join producto as p
        on l.sku = p.sku
)

select
    sale_order_line_sk,
    channel,
    sku,
    category,
    is_catalog_product,
    created_at_utc,
    sale_date,
    cast(date_trunc('month', sale_date) as date) as sale_month,
    quantity_sold,
    quantity_returned,
    quantity_sold - quantity_returned as quantity_net,
    gross_charged,
    taxes,
    revenue_ex_tax,
    returned_revenue,
    -- El titular del report: sin IVA y descontando lo devuelto (D-15).
    revenue_ex_tax - returned_revenue as net_revenue
from enriquecida
