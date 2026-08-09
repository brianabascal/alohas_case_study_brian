-- Suelo de ruido del margen por canal.
--
-- Sirve para cerrar la PREMISA 3: cuando se neutralizan IVA y devoluciones, los
-- cuatro canales quedan a menos de dos decimas. La pregunta es si esas decimas
-- son senal o azar. Aqui se calcula cuanto ruido tiene cada cifra.
--
-- CM1 y el ratio COGS/PVP son cocientes de sumas, no medias simples, asi que su
-- error estandar se estima con el estimador de razon:
--     SE(x/y) ~ s(x_i - R*y_i) / (sqrt(n) * media(y))
-- Si la diferencia entre dos canales es menor que ~2 veces este error, no hay
-- diferencia que explicar.

with base as (
    select
        l.channel,
        p.cost * l.quantity_sold        as coste,
        l.net_sales                     as neto,
        p.base_price * l.quantity_sold  as pvp
    from `alohas-recruiting-study-case.production.fct_sale_order_line` l
    inner join `alohas-recruiting-study-case.production.dim_product` p using (sku)
),

razones as (
    select
        channel,
        sum(coste) / sum(neto) as r_cm,
        sum(coste) / sum(pvp)  as r_pvp
    from base
    group by channel
)

select
    b.channel                                                                    as canal,
    count(*)                                                                     as lineas,
    round(100 * (1 - r.r_cm), 3)                                                 as cm1_pct,
    round(100 * stddev(b.coste - r.r_cm * b.neto)
              / (sqrt(count(*)) * avg(b.neto)), 3)                               as ee_cm1_pct,
    round(100 * r.r_pvp, 3)                                                      as cogs_sobre_pvp_pct,
    round(100 * stddev(b.coste - r.r_pvp * b.pvp)
              / (sqrt(count(*)) * avg(b.pvp)), 3)                                as ee_cogs_sobre_pvp_pct
from base b
inner join razones r on r.channel = b.channel
group by b.channel, r.r_cm, r.r_pvp
order by lineas desc
