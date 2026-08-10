-- Grano: un mes × un canal (sale_month, channel).
--
-- Por qué: el brief pide el grano temporal correcto y la respuesta para el CEO
-- es mensual con YoY contra el mismo mes del año anterior (D-17). En moda,
-- comparar un mes con el anterior es ruido estacional; marketplace no aguanta
-- grano semanal. Contesta las preguntas 6, 9, 10 y 14 de la sección 01.
with mensual as (
    select
        sale_month,
        channel,
        bool_or(is_partial_month) as is_partial_month,

        count(*) as lines,
        sum(quantity_sold) as units_sold,
        sum(quantity_returned) as units_returned,
        sum(gross_charged) as gross_charged,
        sum(revenue_ex_tax) as revenue_ex_tax,
        sum(net_revenue) as net_revenue

    from {{ ref('fct_sale_line') }}
    group by sale_month, channel
),

-- Contra el mismo mes del año anterior, nunca contra el mes anterior: en moda,
-- comparar enero con diciembre es medir la Navidad, no el negocio (D-17).
comparada as (
    select
        mes.*,
        anyo_pasado.net_revenue as net_revenue_prev_year,
        anyo_pasado.is_partial_month as prev_year_is_partial
    from mensual as mes
    left join mensual as anyo_pasado
        on mes.channel = anyo_pasado.channel
        and anyo_pasado.sale_month = cast(mes.sale_month - interval 1 year as date)
)

select
    sale_month,
    channel,
    is_partial_month,

    lines,
    units_sold,
    units_returned,
    round(100.0 * units_returned / nullif(units_sold, 0), 2) as return_rate_pct,

    gross_charged,
    revenue_ex_tax,
    net_revenue,
    round(
        100.0
        * net_revenue
        / nullif(sum(net_revenue) over (partition by sale_month), 0),
        2
    ) as share_of_month_pct,

    -- Marketplace hace unas cien líneas al mes: a ese volumen, un punto suelto es
    -- ruido de muestreo. Su serie se lee con esta media móvil de tres meses, que
    -- se deja vacía en los dos primeros meses en lugar de promediar uno o dos y
    -- dibujar un arranque hundido que no ha pasado.
    case
        when count(*) over tres_meses = 3
            then round(avg(net_revenue) over tres_meses, 2)
    end as net_revenue_3m_avg,

    net_revenue_prev_year,
    -- Si cualquiera de los dos meses está incompleto, la comparación no significa
    -- nada y se deja vacía a propósito.
    case
        when is_partial_month or prev_year_is_partial then null
        else round(
            100.0 * (net_revenue / nullif(net_revenue_prev_year, 0) - 1), 2
        )
    end as yoy_pct

from comparada
window tres_meses as (
    partition by channel
    order by sale_month
    range between interval 2 month preceding and current row
)
order by sale_month, channel
