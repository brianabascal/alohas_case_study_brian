-- Grano: una línea de pedido con ficha de producto (D-09).
--
-- Aquí vive el stack de costes de la sección 03: COGS, transporte imputado y
-- coste de devolución. La escalera de ingresos no se recalcula; se hereda de
-- int_sale_line. Las medidas de escenario (D-18) son columnas nuevas y no
-- pisan la capa reportada.
with linea as (
    select * from {{ ref('int_sale_line') }}
    where is_catalog_product
),

producto as (
    select sku, product_name, cost
    from {{ ref('stg_dim_product') }}
),

-- D-06: pool = envíos que alguna venta referencia; divisor = todas las líneas
-- (también las sin ficha). Los huérfanos quedan fuera.
tarifa as (
    select
        (
            select sum(s.shipping_cost)
            from {{ ref('stg_fct_shipment') }} as s
            where s.shipment_id in (
                select distinct shipment_id
                from {{ ref('stg_fct_sale_order_line') }}
                where shipment_id is not null
            )
        )
        / (
            select count(*)::decimal(18, 6)
            from {{ ref('stg_fct_sale_order_line') }}
        ) as eur_por_linea
),

economics as (
    select
        wholesale_price_realization,
        marketplace_fee,
        return_shipping_multiplier
    from {{ ref('channel_economics') }}
),

costeada as (
    select
        l.sale_order_line_sk,
        l.channel,
        l.sku,
        p.product_name,
        l.category,
        l.sale_date,
        l.sale_month,
        l.quantity_sold,
        l.quantity_returned,
        l.quantity_net,
        l.gross_charged,
        l.taxes,
        l.revenue_ex_tax,
        l.returned_revenue,
        l.net_revenue,

        -- D-19: la prenda no se revende → COGS sobre lo vendido, no sobre lo neto.
        cast(round(p.cost * l.quantity_sold, 2) as decimal(18, 2)) as product_cost,
        cast(
            round(p.cost * l.quantity_net, 2) as decimal(18, 2)
        ) as product_cost_if_restocked,

        -- D-06: tarifa plana; el nombre evita confundirla con fct_shipment.shipping_cost.
        cast(round(t.eur_por_linea, 2) as decimal(18, 2)) as shipping_cost_allocated,

        -- D-21: una vez por línea con devolución, no por unidad.
        cast(
            round(
                case
                    when l.quantity_returned > 0
                        then t.eur_por_linea * e.return_shipping_multiplier
                    else 0
                end,
                2
            ) as decimal(18, 2)
        ) as return_shipping_cost,

        -- Contrafactual fiscal: mismo escaparate, IVA 21% en los cuatro canales.
        cast(
            round(
                l.gross_charged * 0.79 * l.quantity_net / l.quantity_sold,
                2
            ) as decimal(18, 2)
        ) as net_revenue_tax_equalized,

        -- D-18: wholesale factura al 45% del PVP (sobre el ingreso neto).
        cast(
            round(
                l.net_revenue * case
                    when l.channel = 'wholesale' then e.wholesale_price_realization
                    else 1.0
                end,
                2
            ) as decimal(18, 2)
        ) as net_revenue_scenario,

        -- D-18: comisión de marketplace sobre lo cobrado al cliente, neto de
        -- devoluciones en proporción.
        cast(
            round(
                case
                    when l.channel = 'marketplace'
                        then e.marketplace_fee
                            * l.gross_charged
                            * l.quantity_net
                            / l.quantity_sold
                    else 0
                end,
                2
            ) as decimal(18, 2)
        ) as marketplace_fee_eur,

        e.wholesale_price_realization,
        e.marketplace_fee,
        e.return_shipping_multiplier

    from linea as l
    inner join producto as p
        on l.sku = p.sku
    cross join tarifa as t
    cross join economics as e
)

select
    sale_order_line_sk,
    channel,
    sku,
    product_name,
    category,
    sale_date,
    sale_month,
    quantity_sold,
    quantity_returned,
    quantity_net,
    gross_charged,
    taxes,
    revenue_ex_tax,
    returned_revenue,
    net_revenue,
    product_cost,
    product_cost_if_restocked,
    shipping_cost_allocated,
    return_shipping_cost,
    cast(
        round(
            net_revenue
            - product_cost
            - shipping_cost_allocated
            - return_shipping_cost,
            2
        ) as decimal(18, 2)
    ) as contribution_margin,
    net_revenue_tax_equalized,
    net_revenue_scenario,
    marketplace_fee_eur,
    cast(
        round(
            net_revenue_scenario
            - product_cost
            - shipping_cost_allocated
            - return_shipping_cost
            - marketplace_fee_eur,
            2
        ) as decimal(18, 2)
    ) as contribution_margin_scenario,
    wholesale_price_realization,
    marketplace_fee,
    return_shipping_multiplier
from costeada
