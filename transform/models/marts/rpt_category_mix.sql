-- Grano: una categoría de producto (category).
--
-- Por qué: la pregunta 3, la mitad que el canal no explica. Con precio de
-- catálogo fijo y cero descuentos (DQ-06), el ingreso medio por unidad solo
-- puede moverse por mezcla; una fila por categoría compara cuotas entre las
-- dos ventanas anuales. Excluye líneas sin ficha de producto (DQ-01), sin
-- categoría.
with por_categoria as (
    select
        category,

        sum(quantity_sold) filter (where sales_year = 'year_1') as units_sold_y1,
        sum(quantity_sold) filter (where sales_year = 'year_2') as units_sold_y2,
        sum(revenue_ex_tax) filter (where sales_year = 'year_1') as revenue_ex_tax_y1,
        sum(revenue_ex_tax) filter (where sales_year = 'year_2') as revenue_ex_tax_y2,
        sum(net_revenue) filter (where sales_year = 'year_1') as net_revenue_y1,
        sum(net_revenue) filter (where sales_year = 'year_2') as net_revenue_y2

    from {{ ref('fct_sale_line') }}
    where sales_year is not null
        and is_catalog_product
    group by category
),

cuotas as (
    select
        *,
        100.0 * units_sold_y1
        / nullif(sum(units_sold_y1) over (), 0) as share_of_units_y1_pct,
        100.0 * units_sold_y2
        / nullif(sum(units_sold_y2) over (), 0) as share_of_units_y2_pct
    from por_categoria
)

select
    category,

    units_sold_y1,
    units_sold_y2,
    round(share_of_units_y1_pct, 2) as share_of_units_y1_pct,
    round(share_of_units_y2_pct, 2) as share_of_units_y2_pct,
    -- Lo que hay que mirar: cuántos puntos de cuota gana o pierde cada categoría.
    round(share_of_units_y2_pct - share_of_units_y1_pct, 2) as share_change_pp,

    round(revenue_ex_tax_y1 / nullif(units_sold_y1, 0), 2) as revenue_per_unit_y1,
    round(revenue_ex_tax_y2 / nullif(units_sold_y2, 0), 2) as revenue_per_unit_y2,

    net_revenue_y1,
    net_revenue_y2,
    round(
        100.0 * (net_revenue_y2 / nullif(net_revenue_y1, 0) - 1), 2
    ) as net_revenue_growth_pct

from cuotas
order by units_sold_y2 desc
