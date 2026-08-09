-- La escalera de ingresos tiene que cerrar en las 50.000 líneas: lo cobrado menos
-- el impuesto es el ingreso sin IVA, y lo devuelto nunca puede ser más de lo que
-- se ingresó. Si esto falla, cualquier número de la sección 01 está mal.
select
    sale_order_line_sk,
    gross_charged,
    taxes,
    revenue_ex_tax,
    returned_revenue,
    net_revenue
from {{ ref('fct_sale_line') }}
where gross_charged - taxes <> revenue_ex_tax
    or net_revenue < 0
    or net_revenue > revenue_ex_tax
