-- D-06: shipping_cost_allocated es una tarifa plana. Si aparece más de un valor
-- distinto, alguien ha vuelto a heredar el coste del envío línea a línea.
select count(distinct shipping_cost_allocated) as distinct_rates
from {{ ref('int_sale_line_margin') }}
having count(distinct shipping_cost_allocated) <> 1
