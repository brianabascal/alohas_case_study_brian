-- Staging mínimo de humo: tipado + rename. Limpiezas de negocio van después.
with source as (
    select * from {{ source('raw', 'dim_product') }}
)

select
    cast(sku as varchar) as sku,
    cast(name as varchar) as product_name,
    cast(category as varchar) as category,
    cast(base_price as decimal(18, 2)) as base_price,
    cast(cost as decimal(18, 2)) as cost
from source
