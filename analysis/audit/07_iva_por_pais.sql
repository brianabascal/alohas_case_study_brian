-- 07 · Tipo impositivo efectivo por pais de destino.
-- Disparador: 06 mostro un 21% exacto en online, retail y marketplace, pero
-- fct_shipment tiene 8 paises. Si el IVA es el mismo en todos, el impuesto esta
-- calculado a tipo espanol sin considerar el destino, y eso es un problema de
-- dato que afecta a cualquier lectura ex-IVA por geografia.

select
    s.country,
    count(*)                                            as filas,
    round(100 * sum(l.taxes) / sum(l.gross_sale), 2)    as tipo_efectivo_pct,
    count(distinct l.channel)                           as canales,
    round(sum(l.gross_sale), 0)                         as gross_sale
from `alohas-recruiting-study-case.production.fct_sale_order_line` as l
join `alohas-recruiting-study-case.production.fct_shipment` as s
    using (shipment_id)
where l.channel != 'wholesale'
group by s.country
order by gross_sale desc
