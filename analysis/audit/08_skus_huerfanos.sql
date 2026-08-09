-- 08 · Anatomia de los SKUs huerfanos.
-- Disparador: 03 conto 722 SKUs del hecho sin fila en dim_product. Saber si son
-- ruido aleatorio o un patron (una categoria, un canal, una epoca) decide si se
-- excluyen, se imputan o se reportan como incidencia de sincronizacion.

select
    coalesce(l.channel, 'TOTAL')                          as channel,
    count(*)                                              as lineas,
    count(distinct l.sku)                                 as skus,
    min(date(l.created_at))                               as primera,
    max(date(l.created_at))                               as ultima,
    round(sum(l.gross_sale), 0)                           as gross_sale,
    round(avg(l.quantity_sold), 2)                        as unidades_por_linea,
    -- los SKU validos siguen un patron; comparar longitud y prefijo revela si
    -- los huerfanos son de otra familia o del mismo espacio de nombres
    count(distinct length(l.sku))                         as longitudes_distintas,
    string_agg(distinct substr(l.sku, 1, 3) order by substr(l.sku, 1, 3) limit 5) as prefijos
from `alohas-recruiting-study-case.production.fct_sale_order_line` as l
left join `alohas-recruiting-study-case.production.dim_product` as p
    using (sku)
where p.sku is null
group by rollup (l.channel)
order by lineas desc
