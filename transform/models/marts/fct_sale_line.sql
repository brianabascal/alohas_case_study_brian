-- Grano: una línea de pedido (sale_order_line_sk).
--
-- Por qué: es la unidad atómica del dato de ventas y no hay clave natural de
-- pedido ni de línea (D-10). Todo lo que enseña la sección 01 se agrega desde
-- aquí, incluidos los cortes que no tienen su propio modelo (por ejemplo, el
-- mismo periodo mirado en semanas para justificar el grano mensual).
with linea as (
    select * from {{ ref('int_sale_line') }}
),

ventana as (
    select * from {{ ref('int_dataset_window') }}
)

select
    linea.*,

    -- Un mes incompleto se dibuja, pero no se compara (ver int_dataset_window).
    linea.sale_month in (ventana.first_partial_month, ventana.last_partial_month)
        as is_partial_month,

    -- Las dos ventanas de doce meses del crecimiento. Queda a null el primer día
    -- del dataset, que no cabe en ninguna de las dos.
    case
        when linea.sale_date between ventana.year_2_start and ventana.year_2_end
            then 'year_2'
        when linea.sale_date between ventana.year_1_start and ventana.year_1_end
            then 'year_1'
    end as sales_year

from linea
cross join ventana
