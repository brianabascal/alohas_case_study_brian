-- Una sola fila con los límites del dataset y las dos ventanas anuales que se
-- comparan en la sección 01. Se derivan del dato en vez de escribirse a mano: el
-- día que lleguen ventas nuevas, el corte se mueve solo.
with limites as (
    select
        min(sale_date) as first_sale_date,
        max(sale_date) as last_sale_date
    from {{ ref('int_sale_line') }}
)

select
    first_sale_date,
    last_sale_date,

    -- Los meses de los dos extremos están incompletos: mayo de 2024 empieza el 29
    -- y a mayo de 2026 le faltan dos días. Pintados como meses normales, el
    -- primero parece un desplome y el último una caída que solo existe en el
    -- calendario, así que se marcan y no entran en ninguna comparativa.
    cast(date_trunc('month', first_sale_date) as date) as first_partial_month,
    cast(date_trunc('month', last_sale_date) as date) as last_partial_month,

    -- Dos ventanas de 365 días ancladas en la fecha de corte, para que el
    -- crecimiento compare periodos iguales. El precio de hacerlo así es que el
    -- primer día del dataset (29-05-2024) se queda fuera de las dos.
    cast(last_sale_date - interval 2 year + interval 1 day as date) as year_1_start,
    cast(last_sale_date - interval 1 year as date) as year_1_end,
    cast(last_sale_date - interval 1 year + interval 1 day as date) as year_2_start,
    last_sale_date as year_2_end
from limites
