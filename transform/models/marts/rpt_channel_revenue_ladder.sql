-- Grano: un canal, más la fila TODOS del rollup (channel).
--
-- Por qué: las preguntas 1, 4 y 5 miran el periodo completo, no el tiempo. Una
-- fila por canal basta para enseñar la escalera cobrado → neto y cómo cambia el
-- ranking en cada peldaño (wholesale no paga impuesto y devuelve cuatro veces
-- menos que online: tres peldaños, tres ordenaciones; esa es la respuesta a
-- "are we comparing like for like"). TODOS es el negocio entero.
with por_canal as (
    select
        coalesce(channel, 'TODOS') as channel,

        count(*) as lines,
        sum(quantity_sold) as units_sold,
        sum(quantity_returned) as units_returned,

        sum(gross_charged) as gross_charged,
        sum(taxes) as taxes,
        sum(revenue_ex_tax) as revenue_ex_tax,
        sum(returned_revenue) as returned_revenue,
        sum(net_revenue) as net_revenue,

        -- Lo que la sección 03 no podrá costear, para poder declarar la
        -- diferencia entre el ingreso de esta sección y la base del margen.
        count(*) filter (where not is_catalog_product) as lines_without_catalog,
        sum(net_revenue) filter (where not is_catalog_product)
            as net_revenue_without_catalog

    from {{ ref('fct_sale_line') }}
    group by rollup (channel)
)

select
    channel,
    lines,
    units_sold,
    units_returned,
    round(100.0 * units_returned / units_sold, 2) as return_rate_pct,

    gross_charged,
    taxes,
    revenue_ex_tax,
    returned_revenue,
    net_revenue,

    -- Cuota de cada canal en tres peldaños. El filtro deja fuera la fila TODOS
    -- para que las cuotas sumen 100 y no 50.
    round(
        100.0 * gross_charged
        / sum(gross_charged) filter (where channel <> 'TODOS') over (), 2
    ) as share_of_gross_pct,
    round(
        100.0 * revenue_ex_tax
        / sum(revenue_ex_tax) filter (where channel <> 'TODOS') over (), 2
    ) as share_of_ex_tax_pct,
    round(
        100.0 * net_revenue
        / sum(net_revenue) filter (where channel <> 'TODOS') over (), 2
    ) as share_of_net_pct,

    -- Los dos escalones, en porcentaje de lo que había justo encima.
    round(100.0 * taxes / gross_charged, 2) as tax_pct_of_gross,
    round(100.0 * returned_revenue / revenue_ex_tax, 2) as returns_pct_of_ex_tax,

    lines_without_catalog,
    net_revenue_without_catalog

from por_canal
order by channel = 'TODOS', net_revenue desc
