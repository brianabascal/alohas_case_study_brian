-- El agregado por canal tiene que sumar exactamente lo mismo que el hecho del que
-- sale. Es la prueba de que el report y el dato no se separan por el camino.
with del_hecho as (
    select
        sum(gross_charged) as gross_charged,
        sum(net_revenue) as net_revenue
    from {{ ref('fct_sale_line') }}
),

del_report as (
    select
        gross_charged,
        net_revenue
    from {{ ref('rpt_channel_revenue_ladder') }}
    where channel = 'TODOS'
)

select
    del_hecho.gross_charged as gross_charged_hecho,
    del_report.gross_charged as gross_charged_report,
    del_hecho.net_revenue as net_revenue_hecho,
    del_report.net_revenue as net_revenue_report
from del_hecho
cross join del_report
where abs(del_hecho.gross_charged - del_report.gross_charged) > 0.01
    or abs(del_hecho.net_revenue - del_report.net_revenue) > 0.01
