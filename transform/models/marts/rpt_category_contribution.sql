-- Grano: una categoría del catálogo.
--
-- Contesta dónde pesa el transporte plano: la misma tarifa de 4,13 €/línea se
-- come mucho más margen en lo barato (accesorios) que en outerwear.
with por_categoria as (
    select
        category,
        count(*) as lines,
        sum(quantity_sold) as units_sold,
        sum(quantity_returned) as units_returned,
        sum(net_revenue) as net_revenue,
        sum(product_cost) as product_cost,
        sum(shipping_cost_allocated) as shipping_cost_allocated,
        sum(return_shipping_cost) as return_shipping_cost,
        sum(contribution_margin) as contribution_margin
    from {{ ref('int_sale_line_margin') }}
    group by category
)

select
    category,
    lines,
    units_sold,
    units_returned,
    round(100.0 * units_returned / nullif(units_sold, 0), 2) as return_rate_pct,
    net_revenue,
    round(net_revenue / lines, 2) as net_revenue_per_line,
    product_cost,
    shipping_cost_allocated,
    return_shipping_cost,
    contribution_margin,
    round(100.0 * contribution_margin / nullif(net_revenue, 0), 2) as cm_pct,
    round(
        100.0 * shipping_cost_allocated / nullif(net_revenue, 0), 2
    ) as shipping_pct_of_net,
    round(contribution_margin / lines, 2) as cm_per_line
from por_categoria
order by shipping_pct_of_net desc
