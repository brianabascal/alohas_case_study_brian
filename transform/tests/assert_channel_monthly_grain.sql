-- El grano de la serie mensual es un mes y un canal. Si se duplicara, la media
-- móvil y la comparativa contra el año anterior darían números plausibles y
-- falsos, que es la peor clase de error.
select
    sale_month,
    channel,
    count(*) as filas
from {{ ref('rpt_channel_monthly') }}
group by sale_month, channel
having count(*) > 1
