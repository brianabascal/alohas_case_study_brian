-- Grano: un SKU del catálogo.
--
-- Contesta qué productos hacen dinero y cuáles lideran en ingreso pero se caen
-- en CM. Los ranks permiten el contraste revenue-sano / CM-roto del brief.
with por_sku as (
    select
        sku,
        any_value(product_name) as product_name,
        any_value(category) as category,
        count(*) as lines,
        sum(quantity_sold) as units_sold,
        sum(quantity_returned) as units_returned,
        sum(net_revenue) as net_revenue,
        sum(product_cost) as product_cost,
        sum(shipping_cost_allocated) as shipping_cost_allocated,
        sum(return_shipping_cost) as return_shipping_cost,
        sum(contribution_margin) as contribution_margin
    from {{ ref('int_sale_line_margin') }}
    group by sku
)

select
    sku,
    product_name,
    category,
    lines,
    units_sold,
    units_returned,
    round(100.0 * units_returned / nullif(units_sold, 0), 2) as return_rate_pct,
    net_revenue,
    product_cost,
    shipping_cost_allocated,
    return_shipping_cost,
    contribution_margin,
    round(100.0 * contribution_margin / nullif(net_revenue, 0), 2) as cm_pct,
    round(net_revenue / nullif(units_sold, 0), 2) as net_revenue_per_unit,
    round(contribution_margin / nullif(units_sold, 0), 2) as cm_per_unit,
    rank() over (order by net_revenue desc) as revenue_rank,
    rank() over (order by contribution_margin desc) as cm_rank,
    rank() over (order by cm_pct desc) as cm_pct_rank
from por_sku
order by contribution_margin desc
