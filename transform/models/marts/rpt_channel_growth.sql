-- Grano: un canal, más la fila TODOS del rollup (channel).
--
-- Por qué: las preguntas 2, 3, 7 y 8 piden crecimiento y contribución por canal
-- en dos periodos comparables, no una serie temporal. Una fila por canal deja
-- lado a lado year_1 y year_2 (ventanas de 365 días ancladas en la fecha de
-- corte, no años naturales; ver int_dataset_window).
with por_canal as (
    select
        coalesce(channel, 'TODOS') as channel,

        count(*) filter (where sales_year = 'year_1') as lines_y1,
        count(*) filter (where sales_year = 'year_2') as lines_y2,

        sum(quantity_sold) filter (where sales_year = 'year_1') as units_sold_y1,
        sum(quantity_sold) filter (where sales_year = 'year_2') as units_sold_y2,
        sum(quantity_returned) filter (where sales_year = 'year_1') as units_returned_y1,
        sum(quantity_returned) filter (where sales_year = 'year_2') as units_returned_y2,

        sum(revenue_ex_tax) filter (where sales_year = 'year_1') as revenue_ex_tax_y1,
        sum(revenue_ex_tax) filter (where sales_year = 'year_2') as revenue_ex_tax_y2,
        sum(returned_revenue) filter (where sales_year = 'year_1') as returned_revenue_y1,
        sum(returned_revenue) filter (where sales_year = 'year_2') as returned_revenue_y2,
        sum(net_revenue) filter (where sales_year = 'year_1') as net_revenue_y1,
        sum(net_revenue) filter (where sales_year = 'year_2') as net_revenue_y2

    from {{ ref('fct_sale_line') }}
    where sales_year is not null
    group by rollup (channel)
),

crecimiento as (
    select
        *,
        net_revenue_y2 - net_revenue_y1 as net_revenue_growth_eur,
        round(100.0 * (units_sold_y2 / units_sold_y1 - 1), 2) as units_growth_pct,
        round(100.0 * (revenue_ex_tax_y2 / revenue_ex_tax_y1 - 1), 2)
            as revenue_ex_tax_growth_pct,
        round(100.0 * (net_revenue_y2 / net_revenue_y1 - 1), 2) as net_revenue_growth_pct,

        -- Con cero descuentos y precio de catálogo fijo (DQ-06), el ingreso medio
        -- por unidad solo se puede mover porque cambie la mezcla de lo que se
        -- vende. Separarlo del volumen es lo que contesta si crecemos vendiendo
        -- más o vendiendo distinto.
        round(revenue_ex_tax_y1 / units_sold_y1, 2) as revenue_per_unit_y1,
        round(revenue_ex_tax_y2 / units_sold_y2, 2) as revenue_per_unit_y2,

        -- Dos tasas de devolución que no son la misma y no siempre se mueven en
        -- la misma dirección: una cuenta prendas y la otra cuenta euros. La de
        -- unidades es la operativa; la de valor es el peldaño de la escalera y es
        -- la que explica el ingreso neto.
        round(100.0 * units_returned_y1 / units_sold_y1, 2) as return_rate_y1_pct,
        round(100.0 * units_returned_y2 / units_sold_y2, 2) as return_rate_y2_pct,
        round(100.0 * returned_revenue_y1 / revenue_ex_tax_y1, 2) as returned_value_y1_pct,
        round(100.0 * returned_revenue_y2 / revenue_ex_tax_y2, 2) as returned_value_y2_pct
    from por_canal
)

select
    channel,

    lines_y1,
    lines_y2,
    units_sold_y1,
    units_sold_y2,
    units_growth_pct,
    -- El numerador de la tasa de devolución va publicado al lado de la tasa: sin
    -- él no se puede saber si un movimiento de un punto es real o es ruido.
    units_returned_y1,
    units_returned_y2,

    revenue_per_unit_y1,
    revenue_per_unit_y2,
    round(100.0 * (revenue_per_unit_y2 / revenue_per_unit_y1 - 1), 2)
        as revenue_per_unit_growth_pct,

    revenue_ex_tax_y1,
    revenue_ex_tax_y2,
    revenue_ex_tax_growth_pct,

    net_revenue_y1,
    net_revenue_y2,
    net_revenue_growth_eur,
    net_revenue_growth_pct,

    -- Cuántos euros del crecimiento del negocio pone cada canal. No es lo mismo
    -- que crecer rápido: un canal pequeño puede doblar y mover menos dinero que
    -- uno grande subiendo un 5%.
    round(
        100.0 * net_revenue_growth_eur
        / sum(net_revenue_growth_eur) filter (where channel <> 'TODOS') over (), 2
    ) as share_of_growth_pct,

    return_rate_y1_pct,
    return_rate_y2_pct,
    returned_value_y1_pct,
    returned_value_y2_pct,

    -- Puntos de crecimiento que el canal gana vendiendo y pierde
    -- devolviendo. Si sale positivo, el canal vende más y se queda igual.
    round(revenue_ex_tax_growth_pct - net_revenue_growth_pct, 2)
        as growth_lost_to_returns_pp

from crecimiento
order by channel = 'TODOS', net_revenue_y2 desc
