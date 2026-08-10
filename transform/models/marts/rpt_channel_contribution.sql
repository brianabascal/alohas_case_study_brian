-- Grano: un canal, más la fila TODOS.
--
-- Port del audit #29 a mart: stack de costes y cuatro lecturas del margen
-- (observado, IVA igualado, sin efecto de devolución, escenario D-18).
with por_canal as (
    select
        coalesce(channel, 'TODOS') as channel,

        count(*) as lines,
        count(*) filter (where quantity_returned > 0) as lines_with_return,
        sum(quantity_sold) as units_sold,
        sum(quantity_returned) as units_returned,

        sum(net_revenue) as net_revenue,
        sum(product_cost) as product_cost,
        sum(shipping_cost_allocated) as shipping_cost_allocated,
        sum(return_shipping_cost) as return_shipping_cost,
        sum(contribution_margin) as contribution_margin,

        sum(net_revenue_tax_equalized) as net_revenue_tax_equalized,
        sum(product_cost_if_restocked) as product_cost_if_restocked,
        sum(net_revenue_scenario) as net_revenue_scenario,
        sum(marketplace_fee_eur) as marketplace_fee_eur,
        sum(contribution_margin_scenario) as contribution_margin_scenario

    from {{ ref('int_sale_line_margin') }}
    group by rollup (channel)
)

select
    channel,
    lines,
    lines_with_return,
    units_sold,
    units_returned,
    round(100.0 * units_returned / units_sold, 2) as return_rate_pct,

    net_revenue,
    product_cost,
    shipping_cost_allocated,
    return_shipping_cost,
    contribution_margin,
    round(100.0 * contribution_margin / net_revenue, 2) as cm_pct,

    -- Lectura 2: mismo escaparate, IVA 21% en todos.
    round(
        100.0
        * (
            net_revenue_tax_equalized
            - product_cost
            - shipping_cost_allocated
            - return_shipping_cost
        )
        / net_revenue_tax_equalized,
        2
    ) as cm_tax_equalized_pct,

    -- Lectura 3: además, la prenda se revende y no cuesta traerla.
    round(
        100.0
        * (
            net_revenue_tax_equalized
            - product_cost_if_restocked
            - shipping_cost_allocated
        )
        / net_revenue_tax_equalized,
        2
    ) as cm_no_return_effect_pct,

    net_revenue_scenario,
    marketplace_fee_eur,
    contribution_margin_scenario,
    round(
        100.0 * contribution_margin_scenario / nullif(net_revenue_scenario, 0),
        2
    ) as cm_scenario_pct

from por_canal
order by channel = 'TODOS', cm_pct desc
