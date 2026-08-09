-- Tablas de contingencia canal x categoria y canal x metodo de envio, en formato
-- largo, para el test de independencia de 23_test_independencia.py.
--
-- Sirven a las PREMISAS 1 y 2: si el canal es independiente de la categoria y
-- del metodo de envio, ninguna de las dos cosas puede explicar una diferencia de
-- rentabilidad entre canales.
--
-- El eje de categoria excluye SKUs huerfanos (no tienen categoria). El eje de
-- metodo de envio usa TODAS las lineas: es una pregunta logistica, no de
-- producto, y las lineas sin envio (DQ-02) son una categoria informativa.

with categoria as (
    select l.channel, p.category as valor
    from `alohas-recruiting-study-case.production.fct_sale_order_line` l
    inner join `alohas-recruiting-study-case.production.dim_product` p using (sku)
),

metodo as (
    select l.channel, ifnull(s.shipping_method, 'sin_envio') as valor
    from `alohas-recruiting-study-case.production.fct_sale_order_line` l
    left join `alohas-recruiting-study-case.production.fct_shipment` s using (shipment_id)
)

select 'categoria' as eje, valor, channel as canal, count(*) as lineas
from categoria
group by eje, valor, canal

union all

select 'metodo_envio' as eje, valor, channel as canal, count(*) as lineas
from metodo
group by eje, valor, canal

order by eje, valor, canal
