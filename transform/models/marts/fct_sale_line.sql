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
    linea.sale_order_line_sk,
    linea.channel,
    linea.sku,
    linea.category,
    linea.is_catalog_product,
    linea.created_at_utc,
    linea.sale_date,
    linea.sale_month,
    linea.quantity_sold,
    linea.quantity_returned,
    linea.quantity_net,
    linea.gross_charged,
    linea.taxes,
    linea.revenue_ex_tax,
    linea.returned_revenue,
    linea.net_revenue,

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
