with source as (
    select * from {{ source('raw', 'fct_shipment') }}
)

select
    cast(shipment_id as varchar) as shipment_id,
    cast(shipping_method as varchar) as shipping_method,
    cast(shipping_cost as decimal(18, 2)) as shipping_cost,
    -- D-11: UK → GB (ISO 3166-1)
    case
        when upper(cast(country as varchar)) = 'UK' then 'GB'
        else upper(cast(country as varchar))
    end as country
from source
