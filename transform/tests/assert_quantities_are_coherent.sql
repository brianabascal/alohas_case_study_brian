-- Nadie puede devolver más de lo que compró, ni comprar cero unidades. Lo segundo
-- importa además porque el reparto de lo devuelto divide entre las unidades
-- vendidas: un cero aquí sería una división por cero silenciosa.
select
    sale_order_line_sk,
    quantity_sold,
    quantity_returned
from {{ ref('fct_sale_line') }}
where quantity_sold <= 0
    or quantity_returned < 0
    or quantity_returned > quantity_sold
