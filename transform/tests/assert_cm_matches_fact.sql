-- El CM agregado del mart de canal (TODOS) tiene que cuadrar con la suma de las
-- líneas costadas. Si no, el report y el hecho se han separado.
with del_hecho as (
    select sum(contribution_margin) as contribution_margin
    from {{ ref('int_sale_line_margin') }}
),

del_report as (
    select contribution_margin
    from {{ ref('rpt_channel_contribution') }}
    where channel = 'TODOS'
)

select
    del_hecho.contribution_margin as cm_hecho,
    del_report.contribution_margin as cm_report
from del_hecho
cross join del_report
where abs(del_hecho.contribution_margin - del_report.contribution_margin) > 0.01
