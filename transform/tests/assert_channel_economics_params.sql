-- Los tres parámetros de la seed tienen que ser exactamente los de D-18 / D-21.
-- Si alguien cambia la CSV sin actualizar decisiones.md, este test falla.
select *
from {{ ref('channel_economics') }}
where abs(wholesale_price_realization - 0.45) > 1e-9
   or abs(marketplace_fee - 0.175) > 1e-9
   or abs(return_shipping_multiplier - 1.0) > 1e-9
   or (
        select count(*) from {{ ref('channel_economics') }}
   ) <> 1
