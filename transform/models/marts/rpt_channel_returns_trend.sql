-- Grano: un canal × un medio año (channel, half_number).
--
-- Por qué: la pregunta 9 pregunta si la tasa de devolución se deteriora.
-- Comparar solo dos años engaña: un medio año flojo mueve el año entero y
-- parece tendencia. Un deterioro real sube tramo tras tramo, así que el
-- periodo se parte en los cuatro medios años que caben en las dos ventanas.
with ventana as (
    select * from {{ ref('int_dataset_window') }}
),

etiquetada as (
    select
        linea.channel,
        linea.sale_date,
        linea.quantity_sold,
        linea.quantity_returned,
        case
            when linea.sale_date < ventana.year_1_start + interval 6 month then 1
            when linea.sale_date < ventana.year_2_start then 2
            when linea.sale_date < ventana.year_2_start + interval 6 month then 3
            else 4
        end as half_number
    from {{ ref('fct_sale_line') }} as linea
    cross join ventana
    where linea.sales_year is not null
),

-- Las fechas reales de cada tramo, para que el gráfico pueda etiquetarlos sin
-- que nadie las escriba a mano.
limites as (
    select
        half_number,
        min(sale_date) as half_start,
        max(sale_date) as half_end
    from etiquetada
    group by half_number
)

select
    etiquetada.channel,
    etiquetada.half_number,
    limites.half_start,
    limites.half_end,
    sum(etiquetada.quantity_sold) as units_sold,
    sum(etiquetada.quantity_returned) as units_returned,
    round(
        100.0
        * sum(etiquetada.quantity_returned)
        / nullif(sum(etiquetada.quantity_sold), 0),
        2
    ) as return_rate_pct
from etiquetada
inner join limites using (half_number)
group by
    etiquetada.channel,
    etiquetada.half_number,
    limites.half_start,
    limites.half_end
order by etiquetada.channel, etiquetada.half_number
