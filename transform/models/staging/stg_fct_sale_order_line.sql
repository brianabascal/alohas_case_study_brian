-- Surrogate key (D-10): no hay PK natural en la línea.
with source as (
    select * from {{ source('raw', 'fct_sale_order_line') }}
),

numbered as (
    select
        *,
        row_number() over (
            order by
                created_at,
                channel,
                sku,
                shipment_id,
                quantity_sold,
                quantity_returned,
                gross_sale,
                taxes,
                net_sales
        ) as _rn
    from source
)

select
    md5(
        concat_ws(
            '||',
            cast(created_at as varchar),
            cast(channel as varchar),
            cast(sku as varchar),
            coalesce(cast(shipment_id as varchar), ''),
            cast(quantity_sold as varchar),
            cast(quantity_returned as varchar),
            cast(gross_sale as varchar),
            cast(taxes as varchar),
            cast(net_sales as varchar),
            cast(_rn as varchar)
        )
    ) as sale_order_line_sk,
    cast(channel as varchar) as channel,
    cast(sku as varchar) as sku,
    cast(shipment_id as varchar) as shipment_id,
    cast(quantity_sold as integer) as quantity_sold,
    cast(quantity_returned as integer) as quantity_returned,
    cast(gross_sale as decimal(18, 2)) as gross_sale,
    cast(taxes as decimal(18, 2)) as taxes,
    cast(net_sales as decimal(18, 2)) as net_sales,
    cast(created_at as timestamp) as created_at
from numbered
