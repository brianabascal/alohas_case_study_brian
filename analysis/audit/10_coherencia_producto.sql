-- 10 · Coherencia del catalogo: existe algun producto que se venda por debajo
-- de su coste, o con precio/coste cero o negativo?
-- Objetivo: descartar (o encontrar) el clasico problema plantado de margen
-- imposible antes de construir nada de la pregunta 03.

select
    category,
    count(*)                                                    as skus,
    countif(cost > base_price)                                  as skus_coste_mayor_que_precio,
    countif(cost <= 0 or base_price <= 0)                       as skus_valor_no_positivo,
    round(min(100 * (base_price - cost) / base_price), 1)       as margen_bruto_min_pct,
    round(avg(100 * (base_price - cost) / base_price), 1)       as margen_bruto_medio_pct,
    round(max(100 * (base_price - cost) / base_price), 1)       as margen_bruto_max_pct,
    round(min(base_price), 2)                                   as precio_min,
    round(max(base_price), 2)                                   as precio_max
from `alohas-recruiting-study-case.production.dim_product`
group by category
order by skus desc
